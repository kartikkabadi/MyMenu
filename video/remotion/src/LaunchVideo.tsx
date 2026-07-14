import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";

type Props = { price: string };

export const LaunchVideo: React.FC<Props> = ({ price }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const intro = spring({ frame, fps, config: { damping: 18, stiffness: 90 } });
  const panel = spring({ frame: Math.max(frame - 42, 0), fps, config: { damping: 16, stiffness: 70 } });
  const features = ["External brightness", "Window snapping", "Option–Tab switcher"];

  return (
    <AbsoluteFill style={{ background: "#050608", color: "#f4f7fb", fontFamily: "Arial, sans-serif", overflow: "hidden" }}>
      <AbsoluteFill style={{ background: "radial-gradient(circle at 25% 8%, rgba(67,128,235,.24), transparent 36%), radial-gradient(circle at 80% 80%, rgba(25,52,98,.25), transparent 42%)" }} />
      <AbsoluteFill style={{ padding: 72, justifyContent: "space-between" }}>
        <div style={{ opacity: intro, transform: `translateY(${interpolate(intro, [0, 1], [36, 0])}px)` }}>
          <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 32, fontWeight: 700 }}><span style={{ display: "grid", placeItems: "center", width: 52, height: 52, borderRadius: 16, color: "#5d9dff", border: "1px solid rgba(93,157,255,.5)" }}>✦</span> MyMonitor</div>
          <div style={{ marginTop: 116, fontSize: 76, lineHeight: .98, fontWeight: 700, letterSpacing: -4 }}>A calmer<br /><span style={{ color: "#5d9dff" }}>Mac.</span></div>
          <div style={{ marginTop: 28, color: "#9aa4b3", fontSize: 28, lineHeight: 1.35, maxWidth: 750 }}>External-display brightness and the useful window shortcuts you actually want.</div>
        </div>

        <div style={{ alignSelf: "center", width: 760, padding: 28, borderRadius: 34, background: "rgba(14,17,24,.88)", border: "1px solid rgba(255,255,255,.16)", boxShadow: "0 34px 90px rgba(0,0,0,.5)", transform: `translateY(${interpolate(panel, [0, 1], [80, 0])}px) scale(${interpolate(panel, [0, 1], [.9, 1])})`, opacity: panel }}>
          <div style={{ display: "flex", alignItems: "center", gap: 18, padding: "8px 8px 24px", fontSize: 28 }}><span style={{ color: "#5d9dff", fontSize: 36 }}>☼</span><div><b>External display</b><small style={{ display: "block", color: "#8993a3", fontSize: 18, marginTop: 4 }}>MyMonitor</small></div><span style={{ marginLeft: "auto", width: 12, height: 12, borderRadius: "50%", background: "#5d9dff" }} /></div>
          <div style={{ display: "flex", alignItems: "center", gap: 18, padding: "20px 10px" }}><span style={{ color: "#8b96a5", fontSize: 26 }}>◐</span><div style={{ position: "relative", flex: 1, height: 8, borderRadius: 10, background: "#313846" }}><div style={{ width: "64%", height: "100%", borderRadius: 10, background: "#5d9dff" }} /><i style={{ position: "absolute", left: "61%", top: -8, width: 24, height: 24, borderRadius: "50%", background: "white" }} /></div><span style={{ color: "#8b96a5", fontSize: 26 }}>☀</span></div>
          <div style={{ margin: "0 10px 22px 54px", color: "#758196", fontSize: 16 }}>Software gamma</div>
          <div style={{ padding: 18, borderRadius: 22, background: "rgba(255,255,255,.04)", border: "1px solid rgba(255,255,255,.1)" }}><div style={{ color: "#8993a3", fontSize: 16, marginBottom: 6 }}>Window tools</div>{features.slice(1).map((feature, index) => <div key={feature} style={{ display: "flex", justifyContent: "space-between", padding: "14px 0", fontSize: 21, borderTop: index ? "1px solid rgba(255,255,255,.08)" : undefined }}>{feature}<span style={{ width: 44, height: 25, borderRadius: 20, background: index === 0 ? "#327cf3" : "#3a414d" }} /></div>)}</div>
          <div style={{ marginTop: 14, padding: "18px 6px 4px", color: "#c4cbd6", fontSize: 20 }}>◉　Show dimming in recordings</div>
        </div>

        <div style={{ opacity: intro, display: "flex", justifyContent: "space-between", alignItems: "end" }}><div style={{ color: "#7f8998", fontSize: 21 }}>Open source under MIT · No account · No analytics</div><div style={{ padding: "15px 22px", borderRadius: 14, background: "#327cf3", fontSize: 24, fontWeight: 700 }}>Buy for {price} ↗</div></div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
