// OpenCode plugin: registers the skills of this repository.
//
// OpenCode clones a plugin installed from git as a whole, so `skills/` sits two
// levels up from here and the skills keep their relative links to `docs/` and
// `git-hooks/`. Nothing else is done: the plugin runs no command.
import path from "node:path"
import { fileURLToPath } from "node:url"

const skillsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../skills")

export const FabnumCicdPlugin = async () => ({
  config: async (config) => {
    config.skills ??= {}
    config.skills.paths ??= []
    if (!config.skills.paths.includes(skillsDir)) config.skills.paths.push(skillsDir)
  },
})
