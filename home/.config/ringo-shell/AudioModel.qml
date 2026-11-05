import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Pipewire devices and playback streams for SettingsPanel's audio pages.
Scope {
  id: model

  // Audio devices. Pipewire objects are untracked unless asked, so every node is
  // tracked to keep descriptions and volumes live.
  readonly property var trackedNodes: Pipewire.nodes.values
  readonly property var outputNodes: trackedNodes.filter(n => model.isAudioNode(n) && n.isSink)
  readonly property var inputNodes: trackedNodes.filter(n => model.isAudioNode(n) && !n.isSink)
  readonly property var streamNodes: trackedNodes.filter(n => model.isStreamNode(n))
  property string audioError: ""

  function mediaClass(node): string {
    const props = node && node.properties ? node.properties : {}
    return String(props["media.class"] || "")
  }

  // An audio device: not a video node and not an application stream.
  function isAudioNode(node): bool {
    return node !== null && node !== undefined && node.audio && !node.isStream
           && model.mediaClass(node).startsWith("Audio/")
  }

  function audioLabel(node): string {
    if (!node) return ""
    return node.description && node.description.length > 0 ? node.description : node.name
  }

  function audioVolume(node): string {
    if (!node || !node.audio) return ""
    return Math.round(node.audio.volume * 100) + "%"
  }

  // Playback streams only: capture streams belong to the input-device page.
  function isStreamNode(node): bool {
    return node !== null && node !== undefined && node.audio && node.isStream
           && model.mediaClass(node).startsWith("Stream/Output/Audio")
  }

  function streamLabel(node): string {
    if (!node) return ""
    const props = node.properties || {}
    const app = String(props["application.name"] || "")
    const media = String(props["media.name"] || "")
    if (app.length > 0 && media.length > 0 && media !== app)
      return app + " · " + media
    return app.length > 0 ? app
         : (node.description && node.description.length > 0 ? node.description : node.name)
  }

  function toggleStreamMute(node): void {
    if (node && node.audio) node.audio.muted = !node.audio.muted
  }

  function adjustStreamVolume(node, direction: int): void {
    if (!node || !node.audio) return
    node.audio.volume = Math.max(0, Math.min(1.5, node.audio.volume + direction * 0.05))
  }

  // Pipewire.defaultAudioSink / defaultAudioSource are read-only: the writable
  // knob is the configured (preferred) default, which WirePlumber then selects.
  function setAudioDefault(node): void {
    if (!node) return
    model.audioError = ""
    try {
      if (node.isSink) Pipewire.preferredDefaultAudioSink = node
      else Pipewire.preferredDefaultAudioSource = node
    } catch (e) {
      model.audioError = "Could not switch the default device: " + e
    }
  }

  function defaultOutputLabel(): string {
    const node = Pipewire.defaultAudioSink
    return node ? model.audioLabel(node) : "None"
  }

  function defaultInputLabel(): string {
    const node = Pipewire.defaultAudioSource
    return node ? model.audioLabel(node) : "None"
  }

  // Keeps every node the audio pages can list live (descriptions, volumes).
  PwObjectTracker {
    objects: model.trackedNodes
  }
}
