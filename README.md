# n4th

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ZennJxD/n4th/refs/heads/main/n4th"))()
```

`n4th` is the stable loader. Every execution downloads `n4th-main.lua` using a unique query to avoid stale cache.

Publish future main-script updates to `n4th-main.lua` on branch `main`. Keep the loader URL unchanged. Updates apply on the next execution, not automatically to an already running session.
