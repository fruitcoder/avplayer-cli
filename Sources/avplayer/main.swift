import ArgumentParser
import AVFoundation
import Foundation

public final class AudioPlayerObservationService {
	public var currentItem: AVPlayerItem? { player.currentItem }
	public var currentDuration: CMTime? { currentItem?.duration }
	public var currentDate: Date? { currentItem?.currentDate() }
	public var currentTime: CMTime? { currentItem?.currentTime() }
	public var isPlaybackLikelyToKeepUp: Bool { currentItem?.isPlaybackLikelyToKeepUp ?? false }
	public var isPlaybackBufferEmpty: Bool { currentItem?.isPlaybackBufferEmpty ?? false }
	public var itemError: Error? { currentItem?.error }

	public var onLoadedRangesChanged: (([CMTimeRange]) -> Void)?
	public var onSeekableRangeChanged: ((CMTimeRange) -> Void)?

	public var onItemPlayedToEndTime: (() -> Void)?
	public var onItemFailedToPlayToEndTime: ((Error?) -> Void)?
	public var onItemStatusChanged: ((AVPlayerItem.Status) -> Void)?
	public var onItemNewAccessLogEvent: ((AVPlayerItemAccessLogEvent) -> Void)?
	public var onItemNewErrorLogEvent: ((AVPlayerItemErrorLogEvent) -> Void)?

	public var onTimeChanged: ((CMTime?) -> Void)?
	public var onRateChanged: ((Float) -> Void)?
	public var onPlaybackStalled: (() -> Void)?
	public var onExternalPlaybackActive: ((Bool) -> Void)?
	public var onPlayerStatusChanged: ((AVPlayer.Status) -> Void)?
	public var onPlaybackIsLikelyToKeepUpChanged: ((Bool) -> Void)?

	private let player: AVPlayer
	private var externalPlaybackObservation: Any?
	private var playerStatusObservation: Any?
	private var playerItemStatusObservation: Any?
	private var playerSeekableTimeRangesObservation: Any?
	private var playerLoadedTimeRangesObservation: Any?
	private var playerItemLikelyToKeepUpObservation: Any?
	private var timeObservationToken: Any?
	private var rateObservationToken: Any?

	public init(player: AVPlayer) {
		self.player = player

		setupPlayerObservers()
		setupNotificationCenterObservations()
		setupTimeObservation()
	}

	// swiftlint:disable:next function_body_length
	private func setupPlayerObservers() {
		// maybe observe `isPlaybackLikelyToKeepUp` and `isPlaybackBufferEmpty`

		playerItemLikelyToKeepUpObservation = player.observe(
			\.currentItem?.isPlaybackLikelyToKeepUp,
			changeHandler: { [weak self] player, _ in
				guard let likelyToKeepUp = player.currentItem?.isPlaybackLikelyToKeepUp else { return }
				self?.onPlaybackIsLikelyToKeepUpChanged?(likelyToKeepUp)
			}
		)

		playerStatusObservation = player.observe(
			\.status,
			options: [.new, .initial],
			changeHandler: { [weak self] _, change in
				guard let status = change.newValue ?? change.oldValue else { return }
				print("Player Status changed: \(status)")
				if status == .failed {
					print("Player Status Error: \(String(describing: (self!.player.error as NSError?)!.localizedFailureReason))")
				}
				self?.onPlayerStatusChanged?(status)
			}
		)

		playerItemStatusObservation = player.observe(
			\.currentItem?.status,
			options: [.new, .initial],
			changeHandler: { [weak self] player, _ in
				guard let status = player.currentItem?.status else { return }
				print("Item Status changed: \(status.rawValue)")
				if status == .failed {
					print("Item Status Error: \(String(describing: (self!.player.currentItem?.error as NSError?)!.localizedFailureReason))")
				} else if status == .readyToPlay {
					player.play()
				}
				self?.onItemStatusChanged?(status)
			}
		)

		rateObservationToken = player.observe(
			\.rate,
			options: [.old],
			changeHandler: { [weak self] player, change in
				if let oldValue = change.oldValue, player.rate != oldValue {
					self?.onRateChanged?(player.rate)
				} else if change.oldValue == nil {
					self?.onRateChanged?(player.rate)
				}
			}
		)
	}

	private func setupNotificationCenterObservations() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(itemPlaybackStalled),
			name: .AVPlayerItemPlaybackStalled,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(itemPlayedToEndTime),
			name: .AVPlayerItemDidPlayToEndTime,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(itemFailedToPlayToEndTime),
			name: .AVPlayerItemFailedToPlayToEndTime,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(itemNewAccessLogEntry),
			name: .AVPlayerItemNewAccessLogEntry,
			object: nil
		)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(itemNewErrorLogEntry),
			name: .AVPlayerItemNewErrorLogEntry,
			object: nil
		)
	}

	private func setupTimeObservation() {
		timeObservationToken = player.addPeriodicTimeObserver(
			forInterval: CMTime(seconds: 1, preferredTimescale: 1),
			queue: .main,
			using: { [weak self] time in
				if let date = self?.player.currentItem?.currentDate() {
					print("Date changed \(date)")
				} else {
					print("Time changed \(String(describing: self?.player.currentTime().seconds))")
				}

				self?.onTimeChanged?(time)
			}
		)
	}

	@objc
	private func itemPlaybackStalled() {
		print("Playback stalled")
		onPlaybackStalled?()
	}

	@objc
	private func itemPlayedToEndTime() {
		print("Item did play to end time notification received")
		onItemPlayedToEndTime?()
	}

	@objc
	private func itemFailedToPlayToEndTime(_ notification: Notification) {
		let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
		print("Item did fail to play to end time notification received, error: \(String(describing: error))")
		onItemFailedToPlayToEndTime?(error)
	}

	@objc
	private func itemNewAccessLogEntry(_ notification: Notification) {
		guard
			let playerItem = notification.object as? AVPlayerItem,
			let newestLogEntry = playerItem.accessLog()?.events.last
		else { return }

		print("New Access Log Entry Start")
		print("Event: \(newestLogEntry)")
		print("Indicated Bitrate: \(newestLogEntry.indicatedBitrate)")
		print("Indicated Avereged Bitrate: \(newestLogEntry.indicatedAverageBitrate)")
		print("Playback Start Date: \(String(describing: newestLogEntry.playbackStartDate))")
		print("Playback Session ID: \(String(describing: newestLogEntry.playbackSessionID))")
		print("Playback Start Offset: \(newestLogEntry.playbackStartOffset)")
		print("Playback Type: \(String(describing: newestLogEntry.playbackType))")
		print("Duration Watched: \(newestLogEntry.durationWatched)")
		print("Number Of Stalls: \(newestLogEntry.numberOfStalls)")
		print("URI: \(String(describing: newestLogEntry.uri))")
		print("New Access Log Entry End")

		onItemNewAccessLogEvent?(newestLogEntry)
	}

	@objc
	private func itemNewErrorLogEntry(_ notification: Notification) {
		guard
			let playerItem = notification.object as? AVPlayerItem,
			let newestErrorEntry = playerItem.errorLog()?.events.last
		else { return }

		print("New Error Log Entry Start")
		print("Event: \(newestErrorEntry)")
		print("Date: \(String(describing: newestErrorEntry.date))")
		print("Error Status Code: \(newestErrorEntry.errorStatusCode)")
		print("Error Domain: \(newestErrorEntry.errorDomain)")
		print("Error Comment: \(String(describing: newestErrorEntry.errorComment))")
		print("Playback Session ID: \(String(describing: newestErrorEntry.playbackSessionID))")
		print("URI: \(String(describing: newestErrorEntry.uri))")
		print("New Error Log Entry End")

		onItemNewErrorLogEvent?(newestErrorEntry)
	}
}

final class MetadataObserver: NSObject, AVPlayerItemMetadataOutputPushDelegate {
	var updateCount = 0

	func metadataOutput(
		_ output: AVPlayerItemMetadataOutput,
		didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
		from track: AVPlayerItemTrack?
	) {
		for item in groups.flatMap(\.items) {
			guard let value = item.value as? String, let commonKey = item.commonKey else { continue }
			print("\(updateCount) Metadata Update: \(commonKey.rawValue) => \(value)")
		}
		updateCount += 1
	}
}


let player = AVPlayer()
let observer = AudioPlayerObservationService(player: player)
var outputObserver: MetadataObserver?

struct AVPlay: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "A Swift command-line tool to play remote streams"
	)

	@Argument(help: "The remote url to play")
	private var url: String

	@Flag(help: "Start the player muted")
	private var muted: Bool = false

	@Flag(name: .customLong("metadata-output"), inversion: .prefixedNo)
	var shouldOutputMetadata: Bool = true

	func run() throws {
			guard let itemUrl = URL(string: url) else {
			print("invalid url")
			Foundation.exit(EXIT_FAILURE)
		}

		let item = AVPlayerItem(asset: AVURLAsset(url: itemUrl), automaticallyLoadedAssetKeys: ["duration", "playable"])

		if shouldOutputMetadata {
			outputObserver = MetadataObserver()
			let metadataOutput = AVPlayerItemMetadataOutput(identifiers: nil)
			metadataOutput.setDelegate(outputObserver!, queue: .main)
			item.add(metadataOutput)
		}

		var headRequest = URLRequest(url: itemUrl)
		headRequest.httpMethod = "HEAD"

		URLSession.shared.dataTask(
			with: headRequest,
			completionHandler: { data, response, error in
				guard let httpResponse = response as? HTTPURLResponse else { return }
				print("Headers for \(itemUrl)")

				for (key, value) in httpResponse.allHeaderFields {
					if let stringKey = key as? String, let stringValue = value as? String {
						print("Header \(stringKey): \(stringValue)")
					}
				}
			}
		).resume()

		player.replaceCurrentItem(with: item)
		if #available(OSX 10.12, *) {
			player.automaticallyWaitsToMinimizeStalling = false
		}
		player.isMuted = muted
		player.play()

		RunLoop.main.run()
	}
}

AVPlay.main()
