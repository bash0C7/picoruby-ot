require 'js'

# SynthPatch::WebAdapter: Production adapter using Web Audio API via JS interop.
# Delegates all audio operations to JavaScript functions defined in index.html.
class SynthPatch
  class WebAdapter < AudioAdapter
    def build_graph(json_spec)
      JS.global.synthPatchBuild(json_spec.to_s)
    end

    def note_on(freq, duty, adsr_params)
      JS.global.synthPatchNoteOn(
        freq.to_f,
        duty.to_f,
        adsr_params[:attack].to_f,
        adsr_params[:decay].to_f,
        adsr_params[:sustain].to_f,
        adsr_params[:release].to_f
      )
    end

    def note_off
      JS.global.synthPatchNoteOff
    end

    def update_param(node_name, param, value)
      JS.global.synthPatchUpdateParam(node_name.to_s, param.to_s, value)
    end
  end
end
