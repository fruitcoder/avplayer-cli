# avplayer-cli
AVPlayer wrapper to play hls streams using a cli. I built this to help me debug some hls issues, maybe someone finds another use for it.

Build from source

```
swift build -c release
cd .build/release

// run
avplayer http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/low/ak/bbc_radio_one.m3u8 --muted --no-metadata-output
```

If the `AVPlayerItemMetadataOutput` picks up anything it will print it to the console. 
