# avplayer-cli
AVPlayer wrapper to play hls streams using a cli

Build from source

```
swift build -c release
cd .build/release

// run
avplayer http://a.files.bbci.co.uk/media/live/manifesto/audio/simulcast/hls/nonuk/low/ak/bbc_radio_one.m3u8 --muted --no-metadata-output
```

