# Sourced by both Dock launchers: patch 0018 appends these switches to every Storyline.exe launch, including ones the Desktop App starts.
# --disable-gpu: CEF's ANGLE/D3D11 GPU process cannot initialise under Wine and otherwise restarts in a loop.
# --in-process-gpu: winemac can't show another process's drawing in a child window, so CEF's compositor must run inside Storyline or Preview and web panels stay blank.
# --enable-features=NetworkServiceInProcess2: each CEF helper process is another Storyline.exe that boots .NET again, so the network service runs as a thread instead.
export WINE_APPEND_ARGS="Storyline.exe=--disable-gpu --in-process-gpu --enable-features=NetworkServiceInProcess2"
