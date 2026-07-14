# MyMonitor launch video

This directory keeps two reproducible, code-first versions of the same short vertical product launch video:

- `hyperframes/index.html` is the HTML/CSS composition for HyperFrames.
- `remotion/` is the React composition for Remotion.

Both render a 1080×1920, 12-second social video with the same product story and MyMonitor visual tokens.

## Install

```bash
cd video
npm install
mkdir -p out
```

## HyperFrames

```bash
npm run hyperframes:lint
npm run hyperframes:preview
npm run hyperframes:render
```

## Remotion

```bash
npm run remotion:studio
npm run remotion:render
```

The generated MP4 files are intentionally ignored by Git. Keep the source compositions and attach the final render to the launch post after review.
