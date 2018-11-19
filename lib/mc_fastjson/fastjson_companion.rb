# frozen_string_literal: true frozen_string_literal: true

require 'active_support/concern'

module McFastjson
  module FastjsonCompanion
    extend ActiveSupport::Concern

    CONTENT_TYPE = "application/vnd.api+json"
    SORT_DESC = 'DESC'

    included do
      before_action :parse_include_param, only: [:show, :index]
      before_action :parse_sort_param, only: [:index]
      before_action :load_resource, only: [:show, :update, :destroy]
      before_action :load_resource_collection, only: [:index]

      after_action :verify_authorized
    end

    def index
      authorize(@resource_collection)
      serialize(@resource_collection)
    end

    def show
      authorize(@resource)
      serialize(@resource)
    end

    def create
      @resource = build_resource
      authorize(@resource)

      if @resource.save
        serialize(@resource)
      else
        render_validation_errors
      end
    end

    def destroy
      authorize(@resource)

      @resource.destroy
      head :no_content
    end

    private

    def build_resource
      default_scope.new(create_params)
    end


    def request_options
      @_request_options ||= { params: {} }
    end

    def default_scope
      policy_scope(resource_type)
    end

    def create_params
      params.fetch(:data, {}).fetch(:attributes, {}).permit(policy(resource_type).permitted_attributes)
    end

    def parse_sort_param
      if params[:sort]
        request_options[:sorting] = params[:sort].split(",").map do |x|
          if x[0] == "-"
            x[0] = ""
            "#{x} #{SORT_DESC}"
          else
            x
          end
        end
      end
    end

    def parse_include_param
      if params[:include].present?
        request_options[:params][:include] = request_options[:include] = params[:include].split(",")
      end
    end

    # convert [{"attr" => []}] to ["attr"]
    def prune_leaves(includes)
      includes.map do |included|
        pruned = included
        if included.is_a?(Hash)
          if included.values == [[]]
            pruned = included.keys.first
          else
            included.each do |k, v|
              pruned[k] = prune_leaves(v)
            end
          end
        end
        pruned
      end
    end

    def parse_active_record_includes(include_option)
      result = []
      include_option.each do |option|
        if option.include?('.')
          # parse the dot notation
          partials = option.split('.')
          current_place = result
          while curr_option = partials.shift
            if found = current_place.detect { |h| h.keys.include? curr_option }
              current_place = found[curr_option]
            else
              new_option = { curr_option => [] }
              current_place << new_option
              current_place = new_option[curr_option]
            end
          end
        elsif result.none? { |h| h.keys.include? option }
          result << { option => [] } unless result.include?(option)
        end
      end
      result = include_overrides(result) if respond_to?(:include_overrides)
      result = prune_leaves(result)
      result
    end

    def load_resource
      id = params[:id]
      @resource = if resource_type.respond_to?(:friendly)
        default_scope.friendly.find(id)
      else
        default_scope.find(id)
      end
    end

    def load_resource_collection
      @resource_collection = default_scope
      request_options[:is_collection] = true
      apply_includes
      apply_filters
      apply_sorting
      apply_pagination
    end

    def apply_includes
      return if request_options[:include].blank?
      authorize_includes
      ar_includes = parse_active_record_includes(request_options[:include])
      @resource_collection = @resource_collection.includes(ar_includes)
    end

    def apply_filters
      return if params[:filter].blank?

      if respond_to?(:filter_resources, true)
        filter_resources
      else
        raise ActionController::UnpermittedParameters, ["filter=#{params[:filter]}"]
      end
    end

    def apply_sorting
     return if request_options[:sorting].blank?
      @resource_collection = @resource_collection.order(request_options[:sorting])
    end

    def apply_pagination
      return if params[:page].blank?
      @resource_collection = @resource_collection.limit(params[:page][:limit])
      if params[:page][:offset]
        @resource_collection = @resource_collection.offset(params[:page][:offset])
      end
    end

    # params[:include] must be whitelistd
    # params[:include] can not go further than 1 nested relationship ("attr1.attr2")
    def authorize_includes
      illegal = request_options[:include] - policy(resource_type).permitted_include_params
      deep_nesting = request_options[:include].select { |opt| opt.count(".") > 1 }
      if illegal.present? or deep_nesting.present?
        illegal_params = (illegal + deep_nesting).map { |p| "include=#{p}" }
        raise ActionController::UnpermittedParameters, illegal_params
      end
    end

    def serialize(object_or_collection)
      serialized_json = serializer_type.new(object_or_collection, request_options).serialized_json
      render json: serialized_json
    end
  end
end
