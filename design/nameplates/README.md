# Nameplate Designer

The research and design page for the nameplates pass (November 23, 2026).
Nothing in the addon changed with it.

- `index.html` is the Artifact page. It has five tabs:
  - **Designer:** a working model of the proposed anchoring rules, with a switch to compare them with today's v11 rules.
  - **Rules**, **Research**, **Inventory** and **Plan:** reading tabs.
- Saved designs live in the artifact's database, collection `designs`, one document per design: `{ name, savedAt, preset, rules, cfg }`. `cfg.enemy` and `cfg.friendly` use the proposed settings version 12 shape.
- To republish from another machine, publish `index.html` with the Artifact tool, the capability `{ db: {} }`, and the artifact's URL.
