module Juicy
  class TriggerController

    attr_reader :project, :params
    def initialize(project, params)
      @project = Project.find_or_create_by(name: project)
      @params = params
    end

    def build!
      Build.new(parent: project.name, command: build_command).tap do |build|
        # The seperation of concerns around this madness is horrifying
        construct_environment(build)
        build.save!
        $build_queue << build
      end
    end

    def construct_environment(build)
      env = sanitized_environment
      begin
        env.merge(JSON.load(params['environment']))
      rescue JSON::ParserError
        build.warn!("Failed to parse environment")
      end
      build[:environment] = env
    end

    def build_command
      # TODO Throw 422 not acceptable if missing
      params['command'].tap do |c|
        raise "No command given" if c.nil?
      end
    end

    def sanitized_environment
      ENV.to_hash.tap do |env|
        %w[RUBYOPT BUNDLE_GEMFILE RACK_ENV MONGOLAB_URI].each do |var|
          env[var] = nil
        end
        env["BUNDLE_CONFIG"] = "/nonexistent"
      end
    end

  end
end
