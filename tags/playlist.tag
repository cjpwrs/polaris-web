<playlist>

	<div class="paneHeader">
		<h2>Playlist</h2>
		<div class="playlistOperations">

			<span class="noselect" onclick={ onClickSave }><i class="material-icons md-18">save</i>
				<playlist-save if={ saving } tracks={ tracks } name={ playlistName } />
			</span>

			<span class="noselect" onclick={ onClickClear }><i class="material-icons md-18">delete</i></span><span class="playbackOrder">
				Order:
				<select ref="playbackOrder" onchange={ onChangePlaybackOrder }>
					<option value="default">Default</option>
					<option value="random">Random</option>
					<option value="repeat-track">Repeat Track</option>
					<option value="repeat-all">Repeat All</option>
				</select>
			</span>
		</div>
	</div>

	<div class="paneContent" ref="scrollElement" ondragover={ allowDrop } ondrop={ onDrop }>
		<div style="height: { scrollOffset * itemHeight }px"></div>
		<table>
			<tbody>
				<tr class={ track:true, nowPlaying: (track == currentTrack) } each={ track in tracks.slice( scrollOffset, scrollOffset + pageSize ) } no-reorder onclick={ onClickTrack }>
					<td class="remove"><div class="remove noselect" onclick={ onClickRemoveTrack }>[-]</div></td>
					<td class="nowPlaying"><i if={ track == currentTrack } class="nowPlaying material-icons md-16">play_arrow</i></td>
					<td class="text">{ track.info.album_artist || track.info.artist } - { track.info.album } ({ track.info.year })</td>
					<td class="text song">
						{ track.info.track_number }. { track.info.title }
						<span class="trackArtist" if={ track.info.album_artist && track.info.artist && track.info.album_artist != track.info.artist }>
							({ track.info.artist })
						</span>
					</td>
				</tr>
			</tbody>
		</table>
		<div style="height: { (tracks.length - scrollOffset - pageSize) * itemHeight }px"></div>
		<div class="help" if={ tracks.length == 0 }>
			<i class="material-icons md-48">queue</i><br/>
			Make a playlist by dragging music<br/>from your collection to here.
		</div>
	</div>

	<script>

		this.pageSize = 50;
		this.pagePadding = 6;
		this.itemHeight = 30; // Also defined in CSS

		this.on('mount', function() {
			this.loadFromDisk();
			this.refs.scrollElement.onscroll = function() {
				var newOffset = Math.max(0, Math.floor(this.refs.scrollElement.scrollTop / this.itemHeight) - this.pagePadding );
				newOffset = 2 * Math.floor(newOffset / 2); // Preserve odd/even row indices
				if (newOffset == this.scrollOffset) {
					return;
				}
				this.scrollOffset = newOffset;
				this.update();
			}.bind(this);
		});

		loadFromDisk() {
			var playbackOrder = utils.loadUserData("playbackOrder");
			if (playbackOrder) {
				this.refs.playbackOrder.value = playbackOrder;
			}
			var tracks = utils.loadUserData("playlist");
			if (tracks) {
				this.tracks = tracks;
			}
			var currentTrackIndex = utils.loadUserData("currentTrackIndex");
			if (currentTrackIndex && currentTrackIndex >= 0 && currentTrackIndex < this.tracks.length) {
				var newTrack = this.tracks[currentTrackIndex];
				eventBus.trigger("playlist:jumpTo", newTrack);
			}
			this.playlistName = utils.loadUserData("playlistName")
		}

		clear() {
			this.scrollOffset = 0;
			this.playlistName = null;
			this.tracks = [];
			this.update();
		}

		queueTrackInternal(track) {
			var playlistTrack = {};
			playlistTrack.info = track;
			this.tracks.push(playlistTrack);
		}

		queueTrack(track) {
			this.queueTrackInternal(track);
			this.saveLocalPlaylist();
			this.update();
		}

		queueTracks(tracks) {
			for (var i = 0; i < tracks.length; i++) {
				this.queueTrackInternal(tracks[i]);
			}
			this.saveLocalPlaylist();
			this.update();
		}

		queueURL(url) {
			fetch(url, { credentials: "same-origin" })
			.then(function(res) {
				return res.json();
			})
			.then(function(data) {
				var length = data.length;
				for (var i = 0; i < length; i++) {
					data[i].url = "api/serve/" + encodeURIComponent(data[i].path);
					if (data[i].album && data[i].artwork) {
						data[i].artworkURL = "api/serve/" + encodeURIComponent(data[i].artwork);
					}
				}
				this.queueTracks(data);
			}.bind(this))
		}

		queueDirectory(path) {
			this.queueURL('api/flatten/' + path);
		}

		queuePlaylist(name) {
			this.queueURL('api/playlist/read/' + name);
			this.onPlaylistQueued(name);
		}

		advance(currentTrack, delta) {
			var playbackOrder = this.refs.playbackOrder.selectedOptions[0].value;
			var numTracks = this.tracks.length;

			var newTrack = null;
			if (numTracks > 0) {
				if (playbackOrder == "random") {
					var newTrackIndex = Math.floor(Math.random() * numTracks);
					newTrack = this.tracks[newTrackIndex];
				} else if (playbackOrder == "repeat-track") {
					newTrack = currentTrack;
				} else {
					var currentTrackIndex = this.tracks.indexOf(currentTrack);
					if (currentTrackIndex < 0) {
						newTrack = this.tracks[0];
					} else {
						var newTrackIndex = currentTrackIndex + delta;
						if (newTrackIndex >= 0 && newTrackIndex < numTracks) {
							newTrack = this.tracks[newTrackIndex];
						} else if (playbackOrder == "repeat-all") {
							if (delta > 0) {
								newTrack = this.tracks[0];
							} else {
								newTrack = this.tracks[this.tracks.length - 1];
							}
						}
					}
				}
			}

			if (newTrack != null) {
				this.playTrack(newTrack);
			}
			this.snapToCurrentTrack();
		}

		playPrevious(currentTrack) {
			return this.advance(currentTrack, -1);
		}

		playNext(currentTrack) {
			return this.advance(currentTrack, 1);
		}

		playTrack(playlistTrack) {
			eventBus.trigger("playlist:play", playlistTrack);
		}

		snapToCurrentTrack() {
			var currentTrackIndex = this.tracks.indexOf(this.currentTrack);
			if (currentTrackIndex < 0) {
				return;
			}
			this.refs.scrollElement.scrollTop = (currentTrackIndex - 10) * this.itemHeight;
		}

		onClickTrack(e) {
			this.playTrack(e.item.track);
		}

		onDrop(e) {
			e.preventDefault();
			var item = e.dataTransfer.getData("text/json");
			item = JSON.parse(item);
			var variant = item.variant;
			if (variant == "Song") {
				this.queueTrack(item.fields);
				this.update();
			} else if (variant == "Directory") {
				this.queueDirectory(item.fields.path);
			} else if (variant == "Playlist") {
				this.queuePlaylist(item.fields.name);
			}
		}

		updateCurrentTrack(track) {
			this.currentTrack = track;
			this.saveLocalPlaylist();
			this.update();
		}

		onClickRemoveTrack(e) {
			e.stopPropagation();
			var trackIndex = this.tracks.indexOf(e.item.track);
			if (trackIndex >= 0) {
				this.tracks.splice(trackIndex, 1);
			}
			this.saveLocalPlaylist();
		}

		onClickClear() {
			this.clear();
			this.saveLocalPlaylist();
		}

		allowDrop(e) {
			e.preventDefault();
			return false;
		};

		onChangePlaybackOrder(e) {
			var playbackOrder = this.refs.playbackOrder.selectedOptions[0].value;
			utils.saveUserData("playbackOrder", playbackOrder);
		}

		onPlaylistQueued(playlistName) {
			this.playlistName = playlistName;
		}

		saveLocalPlaylist() {
			if (utils.saveUserData("playlist", this.tracks)) {
				utils.saveUserData("playlistName", this.playlistName);
				var currentTrackIndex = this.tracks.indexOf(this.currentTrack);
				utils.saveUserData("currentTrackIndex", currentTrackIndex);
			}
		}

		onClickSave() {
			this.saving = true;
		}

		endSave(playlistName) {
			this.playlistName = playlistName;
			this.saving = false;
			this.update();
		}

		eventBus.on("browser:queueTrack", this.queueTrack);
		eventBus.on("browser:queueTracks", this.queueTracks);
		eventBus.on("browser:queueDirectory", this.queueDirectory);
		eventBus.on("browser:queuedPlaylist", this.onPlaylistQueued);
		eventBus.on("player:trackFinished", this.playNext);
		eventBus.on("player:playPrevious", this.playPrevious);
		eventBus.on("player:playNext", this.playNext);
		eventBus.on("player:playing", this.updateCurrentTrack);
		eventBus.on("playlist-save:cancel", this.endSave);
		eventBus.on("playlist-save:done", this.endSave);

		this.clear();

	</script>

	<style>

		.paneHeader {
			overflow: visible !important;
		}

		.paneContent {
			padding-left: 0;
			padding-right: 0;
			overflow-anchor: none;
		}

		.playbackOrder {
			color: #DDD;
		}

		.playlistOperations {
			height: 20px;
		}

		.playlistOperations span {
			vertical-align: top;
			font-size: 0.875rem;
		}

		.playlistOperations > span {
			cursor: pointer;
			color: #AAA;
			padding-right: 8px;
		}

		.track {
			cursor: default;
			white-space: nowrap;
		}

		.track:not(:hover) .remove {
			color: transparent;
		}

		.remove {
			cursor: pointer;
		}

		table {
			width: 100%;
			border-spacing: 0;
		}

		tr {
			height: 30px; /*Used in JS*/
		}

		tr:nth-child(2n) {
			background-color: #F2F2F2;
		}

		td {
			padding-bottom: 3px;
			vertical-align: bottom;
			font-size: 0.8125rem;
		}

		.remove, playlist .nowPlaying {
			width: 25px;
		}

		.remove, playlist td.nowPlaying {
			text-align: center;
		}

		td.text {
			max-width: 0;
			overflow: hidden;
			text-overflow: ellipsis;
			white-space: nowrap;
			padding-right: 30px;
		}

		td.song {
			width: 65%;
		}

		td.song .trackArtist {
			color: #AAA;
		}

		tr.nowPlaying td.song .trackArtist {
			color: #B3F4FF;
		}

		tr.nowPlaying td, tr.nowPlaying td * {
			color: #FFF;
			font-weight: 600;
			background-color: #44C8F1;
		}

		.material-icons.nowPlaying {
			vertical-align: middle;
			padding-bottom: 2px;
		}

		.help {
			position: absolute;
			top: 40%;
			width: 100%;
			text-align:center;
			font-size: 1.375rem;
		}

		.help, .help i {
			color: #AAA;
		}
	</style>

</playlist>
