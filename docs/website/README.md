# Claude Pocket Checker — website kit

Prepared for AngeloDeleon.com. No website files or deployment were changed.

| File | Destination / use |
| --- | --- |
| `project-card.json` | Add the object to `src/data/projects.ts`; number `07` assumes the current five projects. |
| `project-story.json` | Merge the slug-keyed object into `src/data/project-stories.ts`. It matches `ProjectStory`: title, reviewedDate, description, answer, sections, FAQs and links. |
| `checking-the-model-before-sending-the-prompt.md` | Copy to `src/content/writing/`; it uses the site's frontmatter schema and remains `draft: true` until editorial approval. |
| `../assets/hero.svg` / `hero.png` | Project image; copy to `src/assets/projects/claude-pocket-checker.svg` and add an import/map entry in `ProjectArt.astro`. |
| `../assets/hero.svg` | Blog image; copy to `public/images/writing/claude-pocket-checker-hero.svg`. |
| `../assets/social-card.png` | 1280×640 portable social/GitHub repository image. |

The graphics are illustrations with synthetic data, not product screenshots or benchmark evidence. SVG sources and a macOS AppKit renderer are included for edits. No remote fonts or scripts are embedded.

The project-card fields and project-story object follow the site's existing BrowserHelm, Agent Watchtower, SocialCanvas, Vibesomnia and BrowserRAD structure. The blog follows its `project-update` template: motivation, problem, changes, code, verification and next steps. Keep `draft: true` until the text and final repository/release links are reviewed.

Before integrating, check any newer site schema changes, add the artwork map entry, run the site's normal type/build checks and verify the project and writing routes. This kit itself is not a live site update.
