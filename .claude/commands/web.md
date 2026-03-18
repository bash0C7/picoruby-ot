# /web — Web Synth Server Command

Start, stop, or check the local WEBrick development server for the web synthesizer.

## Usage

```
/web [start|stop|restart|status]
```

- `start` (default) — Start WEBrick server on port 8000 and open Chrome
- `stop` — Stop the running server
- `restart` — Stop then start
- `status` — Check if server is running

## Instructions

When this command is invoked:

1. Read the `$ARGUMENTS` variable to determine the subcommand (default: `start`)
2. Run the appropriate rake task via Bash:
   - `start`   → `rake server:start`
   - `stop`    → `rake server:stop`
   - `restart` → `rake server:restart`
   - `status`  → `rake server:status`
3. Report the result to the user in Japanese with ピョン suffix

## Example

User runs `/web` or `/web start`:
- Execute `rake server:start` in the project root
- Server starts at http://localhost:8000/
- Chrome opens automatically

User runs `/web stop`:
- Execute `rake server:stop`
- Confirm server has stopped
