# frozen_string_literal: true

module RespondoGrpc
  # Short names: `render_ok`, `render_not_found`, ... Each one simply calls its
  # render_grpc_* twin.
  #
  # Opt-in per service. The names are the same ones the respondo (JSON) gem uses
  # in controllers, so they are never mixed in automatically:
  #
  #   class UserService < Example::Users::V1::UserService::Service
  #     include RespondoGrpc::ShortHelpers
  #
  #     def get_user(request, call)
  #       render_ok(data: User.find(request.id), call: call)   # same as render_grpc_ok
  #     end
  #   end
  module ShortHelpers
    def self.included(base)
      base.include(ServiceHelpers)
      return unless defined?(::Respondo::ControllerHelpers) && base.ancestors.include?(::Respondo::ControllerHelpers)

      warn "[respondo-grpc] #{base} includes RespondoGrpc::ShortHelpers while respondo's JSON helpers " \
           "are available: render_ok & co. now answer in gRPC in this class. " \
           "Use render_grpc_* everywhere if it also needs JSON."
    end

    (ServiceHelpers::SUCCESS_HELPERS.keys + ServiceHelpers::ERROR_HELPERS.keys).each do |name|
      define_method(:"render_#{name}") do |**options|
        public_send(:"render_grpc_#{name}", **options)
      end
    end
  end
end
