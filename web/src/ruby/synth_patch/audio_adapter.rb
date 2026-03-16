# SynthPatch::AudioAdapter: Abstract interface for audio backend.
# Subclasses implement Web Audio API or mock for testing.
class SynthPatch
  class AudioAdapter
    def build_graph(json_spec)
      raise NotImplementedError, "#{self.class}#build_graph not implemented"
    end

    def note_on(freq, duty, adsr_params)
      raise NotImplementedError, "#{self.class}#note_on not implemented"
    end

    def note_off
      raise NotImplementedError, "#{self.class}#note_off not implemented"
    end

    def update_param(node_name, param, value)
      raise NotImplementedError, "#{self.class}#update_param not implemented"
    end
  end
end
