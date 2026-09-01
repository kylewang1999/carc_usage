First exit the hanging CLI with Ctrl-C.

Then run:

```bash
pgrep -af 'codex|app-server'
```

If you see old codex app-server, pid-update-loop, VS Code Codex, or other Codex processes, that's significant.

Reset all Codex processes on this compute node

This will terminate your Codex sessions on this node, including a VS Code Codex session if one is connected. It will not kill your training jobs just because they're running in the same shell account.

```
pkill -TERM -u "$USER" -f codex
sleep 3
pgrep -af 'codex|app-server'
```


If anything Codex-related remains:

```
pkill -KILL -u "$USER" -f codex
sleep 1
pgrep -af 'codex|app-server'
```

Then move the potentially stale app-server runtime state out of the way rather than deleting it:

```
ts=$(date +%Y%m%d-%H%M%S)

[ -e ~/.codex/app-server-control ] && \
  mv ~/.codex/app-server-control ~/.codex/app-server-control.stale-$ts

[ -e ~/.codex/app-server-daemon ] && \
  mv ~/.codex/app-server-daemon ~/.codex/app-server-daemon.stale-$ts
```

This is particularly relevant because Codex has an open Linux bug involving a stale ~/.codex/app-server-control/app-server-control.sock, and another recent issue documents recovery from an old/stuck daemon by terminating it and allowing Codex to recreate the server state.