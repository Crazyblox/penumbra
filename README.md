# About:
Penumbra is performant modular graphics rendering pipeline which leans into Luau's strengths.
This provides developers who wish to render shaders in constrained environments (ie. no GPU access).
The project contains many example fragment shaders to get started, and is configured by default to run `fragment/multi.luau`.
Each major module has its purpose described at the top, and comments are provided to help for context.

# Setup:
The Penumbra directory needs to be sat as a direct child of the Pajamas directory in order to run.
Ensure you get it set up successfully in your host runtime before continuing.
Link: https://github.com/Crazyblox/Pajamas

# Notes - Roblox:
Looking to use this in Roblox?
Make sure to use the 'file sync' feature so that you can load the code directly into Roblox Studio.

# Contributions:
Issues & PRs are welcome; the intent of Penumbra is to remain as minimal and elegant as possible.
What will and what won't be considered is a list I intend to make more clear as the project progresses, but this is a rough start:
- Before making a PR, create an issue for discussion to see if your intent aligns with this projects goals.
- PRs with performance implications will be scrutinised heavily. Ensure optimisation, pros/cons, potential drawbacks and repro testing methods are provided.
- Shader modules which stand out as their own example among the others in the list will be considered; ensure MIT licensing, a source, and adhere to the format in which shader_module outputs.
