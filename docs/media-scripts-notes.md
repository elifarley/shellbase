# Media Conversion Scripts

This document describes scripts for audio/video format conversion and processing.

---

## Scripts

### mkvextract-first.sh

**Purpose**: Extract the first audio track from MKV or WEBM files.

**Usage**:
```bash
mkvextract-first.sh <directory>
```

**What it does**:
- Scans directory for `.webm` and `.mkv` files
- Detects audio codec (Vorbis or Opus) using `mkvinfo`
- Extracts track 0 (first audio track) to separate file
- Output filename: `<input>.opus` or `<input>.ogg`

**Supported codecs**:
- `A_VORBIS` → `.ogg` output
- `A_OPUS` → `.opus` output
- Other → `.unknown` output (will fail)

**Dependencies**:
```bash
sudo apt install mkvtoolnix
```

**Example**:
```bash
# Extract audio from all video files in current directory
mkvextract-first.sh .

# Process video downloads folder
mkvextract-first.sh ~/Downloads/videos
```

---

### opusenc.sh

**Purpose**: Convert WAV files to Opus format with optimized settings.

**Usage**:
```bash
opusenc.sh <file_or_directory> [opusenc_options]
```

**What it does**:
- Accepts single file or directory
- Skips if `.opus` file already exists
- Uses Opus encoding with:
  - `--downmix-mono`: Convert to mono
  - `--artist NotebookLM`: Tag artist
  - `--bitrate 24`: 24 kbps bitrate (voice optimized)
  - Passes additional options to `opusenc`

**Dependencies**:
```bash
sudo apt install opus-tools sox
```

**Example**:
```bash
# Convert single file
opusenc.sh recording.wav

# Convert all WAVs in directory
opusenc.sh ~/Recordings/

# With custom bitrate
opusenc.sh ~/Music/wavs --bitrate 32
```

---

### opusenc-mp3.sh

**Purpose**: Convert MP3 files to Opus format via pipe.

**Usage**:
```bash
opusenc-mp3.sh <directory> [opusenc_options]
```

**What it does**:
- Converts all `.mp3` files in directory
- Uses `sox` to decode MP3 to AIFF (pipe)
- Pipes to `opusenc` for encoding
- Output: `<input>.opus`

**Dependencies**:
```bash
sudo apt install opus-tools sox libsox-fmt-mp3
```

**Example**:
```bash
# Convert MP3 folder to Opus
opusenc-mp3.sh ~/Music/mp3s

# With custom options
opusenc-mp3.sh ~/Music/podcasts --bitrate 32
```

---

## psd-resync.sh

**Purpose**: Trigger Profile Sync Daemon resync.

**Usage**:
```bash
psd-resync.sh
```

**What it does**: Exec wrapper for:
```bash
/usr/bin/profile-sync-daemon resync
```

**What is PSD?** [Profile-sync-daemon](https://github.com/graysky2/profile-sync-daemon) keeps browser profiles in tmpfs and syncs back to disk, similar to the shadowcache system.

---

## Why These Formats?

### Opus vs MP3

| Aspect | Opus | MP3 |
|--------|------|-----|
| Quality | Better at same bitrate | Good at high bitrates |
| Bitrate range | 6-510 kbps | 32-320 kbps |
| Latency | Very low (5-20ms) | Higher |
| Age | 2012 | 1993 |
| Patent free | Yes | Patents expired (2017) |
| Voice optimization | Excellent | Poor |

**At 24 kbps**:
- Opus: Near-transparent for voice
- MP3: Noticeably degraded

**Why 24 kbps?**
- Optimized for voice/podcasts
- Small file size (~1 MB per minute)
- Acceptable quality for speech
- NotebookLM default

### MKV/WEBM Audio Extraction

**Why extract?**
- Video files take significant space
- Audio-only is sufficient for podcasts/lectures
- Can be played on any device

**Why MKV/WEBM?**
- Modern formats with Opus/Vorbis audio
- Common for web downloads (YouTube, etc.)
- MKVToolNix handles them reliably

---

## Installation

### Dependencies

```bash
# MKV extraction
sudo apt install mkvtoolnix

# Opus encoding
sudo apt install opus-tools

# MP3 decoding (for opusenc-mp3.sh)
sudo apt install sox libsox-fmt-mp3

# Profile-sync-daemon (for psd-resync.sh)
sudo apt install profile-sync-daemon
```

### Copy Scripts

```bash
# From shellbase
cp bin/mkvextract-first.sh ~/bin/
cp bin/opusenc.sh ~/bin/
cp bin/opusenc-mp3.sh ~/bin/
cp bin/psd-resync.sh ~/bin/

# Make executable
chmod +x ~/bin/mkvextract-first.sh
chmod +x ~/bin/opusenc.sh
chmod +x ~/bin/opusenc-mp3.sh
chmod +x ~/bin/psd-resync.sh
```

---

## Customization

### Change Opus Bitrate

Edit `opusenc.sh`:
```bash
# Change from 24 to 32 kbps for higher quality
_opusenc() {
  local f="$1"; shift
  test -e "${f%.*}".opus && return
  opusenc --downmix-mono --artist NotebookLM --bitrate 32 "$@" "$f" - > "${f%.*}".opus
}
```

### Change Artist Tag

Edit `opusenc.sh`:
```bash
opusenc --downmix-mono --artist "Your Name" --bitrate 24 "$@" "$f" - > "${f%.*}".opus
```

### Support More Codecs

Edit `mkvextract-first.sh`, add to case statement:
```bash
case "$codec" in
  A_VORBIS) suffix=ogg;;
  A_OPUS) suffix=opus;;
  A_AAC) suffix=aac;;          # Add AAC support
  A_FLAC) suffix=flac;;         # Add FLAC support
  *) suffix=unknown;;
esac
```

---

## Troubleshooting

### mkvextract-first.sh: "codec: unknown"

**Cause**: Audio codec not recognized

**Check**:
```bash
# Identify codec manually
mkvinfo input.mkv | grep -i codec
```

**Solution**: Add codec to case statement (see Customization above)

### opusenc.sh: No output file created

**Cause**: File already exists (script skips existing)

**Check**:
```bash
# Remove existing file
rm output.opus

# Or force overwrite by removing condition from script
```

### opusenc-mp3.sh: "format not recognized"

**Cause**: Missing MP3 decoder for sox

**Fix**:
```bash
sudo apt install libsox-fmt-mp3
```

### psd-resync.sh: Command not found

**Cause**: profile-sync-daemon not installed

**Fix**:
```bash
sudo apt install profile-sync-daemon
```

---

## Related Files

| File | Purpose |
|------|---------|
| `bin/mkvextract-first.sh` | Extract audio from MKV/WEBM |
| `bin/opusenc.sh` | Convert WAV to Opus |
| `bin/opusenc-mp3.sh` | Convert MP3 to Opus |
| `bin/psd-resync.sh` | Profile-sync-daemon resync |
| `bin/backup-prepare.sh` | May use media conversion |
| [backup-scripts-notes.md](backup-scripts-notes.md) | Related backup prep |

---

## References

- [Opus Codec](https://opus-codec.org/)
- [MKVToolNix](https://mkvtoolnix.download/)
- [SoX](http://sox.sourceforge.net/)
- [Profile-sync-daemon](https://github.com/graysky2/profile-sync-daemon)
- [CACHEDIR.TAG Spec](https://bford.info/cachedir/)
