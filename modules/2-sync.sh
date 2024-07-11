module_name=sync

sfb_local_repo_state() {
	local dir="${1:-$PWD}" branch origin common_base local_ref remote_ref
	if [ "$(git -C "$dir" status -s 2>/dev/null)" ]; then
		echo "dirty"; return
	fi
	branch="${2:-$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)}"
	origin="${3:-origin}/$branch"
	common_base=$(git -C "$dir" merge-base $branch $origin 2>/dev/null)
	local_ref=$(git -C "$dir" rev-parse $branch 2>/dev/null)
	remote_ref=$(git -C "$dir" rev-parse $origin 2>/dev/null)
	if [[ -z "$common_base" || -z "$local_ref" || -z "$remote_ref" ]]; then
		echo "unknown"; return
	fi
	if [ "$local_ref" = "$remote_ref" ]; then
		echo "up-to-date"
	elif [ "$local_ref" = "$common_base" ]; then
		echo "behind"
	elif [ "$remote_ref" = "$common_base" ]; then
		echo "ahead"
	else
		echo "diverged"
	fi
}
sfb_git_clone_or_pull() {
	local arg url dir origin branch shallow=0 dir_local cmd=(git) mode state commits
	for arg in "$@"; do
		case "$1" in
			-u) url="$2"; shift ;;
			-d) dir="$2"; shift ;;
			-o) origin=$2; shift ;;
			-b) branch=$2; shift ;;
			-s) shallow=$2; shift ;;
		esac
		shift
	done
	if [ -z "$dir" ]; then
		sfb_error "A specified directory is required to clone or update a local repo!"
	fi
	dir_local="${dir#"$ANDROID_ROOT/"}"
	[[ "$dir_local" = "$HOME"* ]] && dir_local="~${dir_local#"$HOME"}"

	if [ -d "$dir" ]; then
		cmd+=(-C "$dir")
		sfb_dbg "updating $url clone @ $dir_local (shallow: $shallow)..."
		if [ $shallow -eq 0 ]; then
			"${cmd[@]}" pull --recurse-submodules && return || sfb_warn "Failed to pull updates for $dir_local, trying shallow method..."
		else
			"${cmd[@]}" fetch --recurse-submodules --depth 1 || sfb_error "Failed to fetch updates for $dir_local!"
		fi

		state="$(sfb_local_repo_state "$dir" "$branch" "$origin")"
		case "$state" in
			up-to-date) return ;; # no need to update
			behind) : ;; # update out-of-date repo
			diverged)
				commits=$("${cmd[@]}" rev-list --count HEAD) # 1 on shallow clones
				if [ $commits -gt 1 ]; then
					sfb_error "Refusing to update diverged local repo with >1 commit!"
				fi
				;;
			*) sfb_error "Refusing to update '$dir_local' in a state of '$state'!" ;;
		esac
		cmd+=(reset --hard $origin --recurse-submodules)
		mode="update"
	else
		if [ -z "$url" ]; then
			sfb_error "Cannot create a local repo clone without a URL!"
		fi
		cmd+=(clone --recurse-submodules)
		if [ "$branch" ]; then
			cmd+=(-b $branch)
		fi
		if [ $shallow -eq 1 ]; then
			cmd+=(--depth 1)
		fi
		cmd+=("$url" "$dir")
		mode="create"
	fi
	"${cmd[@]}" || sfb_error "Failed to $mode local clone of $url!"
}

sfb_sync_hybris_repos() {
	local ans extra_init_args="" branch="hybris-$HYBRIS_VER" local_manifests_url xml name
	if sfb_array_contains "^\-(y|\-yes)$" "$@"; then
		ans="y"
	fi
	if sfb_array_contains "^\-(s|\-shallow)$" "$@"; then
		extra_init_args+=" --depth 1"
	fi

	if [ ! -d "$ANDROID_ROOT/.repo" ]; then
		#sfb_hook_exec pre-repo-init
		sfb_log "Initializing new $branch source tree..."
		sfb_chroot habuild "repo init -u $REPO_INIT_URL -b $branch --platform=linux$extra_init_args" || return 1
		#sfb_hook_exec post-repo-init
	fi

	if [[ "$REPO_LOCAL_MANIFESTS_URL" && ${#REPO_OVERRIDES[@]} -gt 0 ]]; then
		sfb_error "Do not set REPO_LOCAL_MANIFESTS_URL & REPO_OVERRIDES at the same time!"
	fi

	if [[ ${#REPO_OVERRIDES[@]} -eq 0 && -f "$SFB_OVERRIDES_XML" ]]; then
		sfb_dbg "removing unused sfb repo overrides xml..."
		rm -r "$SFB_LOCAL_MANIFESTS"
	elif [[ ${#REPO_OVERRIDES[@]} -eq 0 && -z "$REPO_LOCAL_MANIFESTS_URL" && \
		    -d "$SFB_LOCAL_MANIFESTS" ]]; then
		sfb_dbg "removing unused local manifests clone..."
		rm -r "$SFB_LOCAL_MANIFESTS"
	fi

	if [ "$REPO_LOCAL_MANIFESTS_URL" ]; then
		sfb_log "Syncing local manifests..."
		local_manifests_url="$(git -C "$SFB_LOCAL_MANIFESTS" config --get remote.origin.url)"
		if [ "$REPO_LOCAL_MANIFESTS_URL" != "$local_manifests_url" ]; then
			sfb_dbg "removing non-matching local manifests ('$REPO_LOCAL_MANIFESTS_URL' != '$local_manifests_url')..."
			rm -r "$SFB_LOCAL_MANIFESTS"
		fi
		sfb_git_clone_or_pull -b $branch -u "$REPO_LOCAL_MANIFESTS_URL" -d "$SFB_LOCAL_MANIFESTS"
	elif [ ${#REPO_OVERRIDES[@]} -gt 0 ]; then
		xml="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<manifest>\n  <!-- Generated by sfbootstrap for $SFB_DEVICE -->\n"
		for name in "${REPO_OVERRIDES[@]}"; do
			xml+="  <remove-project name=\"$name\" />\n"
		done
		xml+="</manifest>"
		sfb_write_if_different "$xml" "$SFB_OVERRIDES_XML"
	fi

	if sfb_manual_hybris_patches_applied; then
		sfb_prompt "Applied hybris patches detected; run 'repo sync -l' & discard ALL local changes (y/N)?" ans "$SFB_YESNO_REGEX" "$ans"
		[[ "${ans^^}" != "Y"* ]] && return
		sfb_chroot habuild "repo sync -l" || return 1
	fi

	#sfb_hook_exec pre-repo-sync
	sfb_log "Syncing $branch source tree with $SFB_JOBS jobs..."
	sfb_chroot habuild "repo sync -c -j$SFB_JOBS --force-sync --fetch-submodules --no-clone-bundle --no-tags" || return 1
	#sfb_hook_exec post-repo-sync
}
sfb_sync_extra_repos() {
	local clone_only=0 i dir_local url dir branch is_shallow extra_args progress
	if [ ${#REPOS[@]} -eq 0 ]; then
		return # no need to setup any extra repos
	fi
	if sfb_array_contains "^\-(c|\-clone-only)$" "$@"; then
		clone_only=1
	fi
	# repo parts => 0:url 1:dir 2:branch 3:is_shallow
	for i in $(seq 0 4 $((${#REPOS[@]}-1))); do
		dir_local="${REPOS[$(($i+1))]}"
		url="${REPOS[$i]}" dir="$ANDROID_ROOT/$dir_local" branch="${REPOS[$(($i+2))]}" is_shallow=${REPOS[$(($i+3))]} extra_args=()
		#sfb_hook_exec pre-repo-sync "$dir"
		progress="$(($(($i+4))/4))/$((${#REPOS[@]}/4))"
		if [ -d "$dir" ]; then
			if [ $clone_only -eq 1 ]; then
				continue # avoid repo updates in clone-only mode
			fi
			sfb_log "Updating extra repo $dir_local ($progress)..."
		else
			sfb_log "Cloning extra repo $dir_local ($progress)..."
		fi
		if [ "$branch" ]; then
			extra_args+=(-b $branch)
		fi
		sfb_git_clone_or_pull -u "$url" -d "$dir" -s $is_shallow "${extra_args[@]}"
		#sfb_hook_exec post-repo-sync "$dir"
	done
}

sfb_sync() {
	if [ "$PORT_TYPE" = "hybris" ]; then
		sfb_sync_hybris_repos "$@" || return 1
	fi
	sfb_sync_extra_repos "$@"
}
sfb_sync_setup_usage() {
	sfb_usage_main+=(sync "Synchronize repos for device")
	sfb_usage_main_sync_args=(
		"-y|--yes" "Answer yes to 'repo sync -l' question automatically on hybris ports"
		"-s|--shallow" "Initialize manifest repos as shallow clones on hybris ports"
		"-c|--clone-only" "Don't attempt to update pre-existing extra repos"
	)
}
