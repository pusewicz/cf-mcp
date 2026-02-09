# Sample Topic

This is a sample topic for testing. It covers audio features in the Cute Framework.

## Music

Load audio from a file using [`cf_audio_load_wav`](../audio/cf_audio_load_wav.md). For .ogg files use [`cf_audio_load_ogg`](../audio/cf_audio_load_ogg.md). Both return a [`CF_Audio`](../audio/CF_Audio.md) struct.

```cpp
CF_Audio song = cf_audio_load_ogg("/music/song.ogg");
cf_music_play(song, 0);
```

## Sound FX

To play a sound call [`cf_play_sound`](../audio/cf_play_sound.md). You get back a [`CF_Sound`](../audio/CF_Sound.md).

See also the [collision](./collision.md) topic for physics sounds.
