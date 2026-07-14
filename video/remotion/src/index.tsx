import { Composition, registerRoot } from "remotion";
import { LaunchVideo } from "./LaunchVideo";

export const RemotionRoot = () => (
  <Composition
    id="MyMonitorLaunch"
    component={LaunchVideo}
    durationInFrames={360}
    fps={30}
    width={1080}
    height={1920}
    defaultProps={{ price: "$2.99" }}
  />
);

registerRoot(RemotionRoot);
