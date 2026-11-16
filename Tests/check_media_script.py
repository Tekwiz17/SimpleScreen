from pathlib import Path
import subprocess
import tempfile

source = Path("SimpleScreen/NowPlaying.swift").read_text()
script = source.split('static let script = #"""', 1)[1].split('"""#', 1)[0]
script = script.replace("function run(argv)", "function playerRun(argv)", 1)
test = r'''
var document, navigator, location;
function run() {
  function require(value, name) { if (!value) throw new Error(name); }
  var media = {paused:false, ended:false, readyState:4, currentTime:15, duration:90,
    play:function(){this.paused=false;return {catch:function(){}};}, pause:function(){this.paused=true;}};
  document = {title:"Fallback", querySelectorAll:function(selector){return selector === "iframe" ? [] : [media];}};
  navigator = {mediaSession:{metadata:{title:"Browser track",artist:"An artist",album:"An album",artwork:[{src:"https://example.com/a.png"}]}}};
  location = {hostname:"example.com"};
  var read = JSON.parse(browserMedia("read"));
  require(read.title === "Browser track" && read.position === 15 && read.state === "playing", "browser metadata");
  browserMedia("toggle"); require(media.paused, "pause");
  browserMedia("toggle"); require(!media.paused, "play");
  browserMedia("next"); require(media.currentTime === 25, "seek forward");
  browserMedia("previous"); require(media.currentTime === 15, "seek back");
  media.currentTime=89; browserMedia("next"); require(media.currentTime===90, "seek clamped");
  media.duration=Infinity; require(JSON.parse(browserMedia("read")).duration===0, "live duration");
  document.querySelectorAll=function(){return [];};
  require(JSON.parse(browserMedia("read")).error.indexOf("No accessible")>=0, "missing media");
  return "8 browser media behavior checks passed.";
}
'''
with tempfile.TemporaryDirectory() as folder:
    path = Path(folder) / "media.js"
    path.write_text(script + test)
    subprocess.run(["/usr/bin/osacompile", "-l", "JavaScript", "-o", str(Path(folder) / "media.scpt"), str(path)], check=True)
    subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", str(path)], check=True)
