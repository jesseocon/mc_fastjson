require 'rails_helper'

describe McFastjson::FastjsonCompanion, type: :controller do
  class AnonTypePolicy < ApplicationPolicy
  end

  class AnonSerializer
    include FastJsonapi::ObjectSerializer

    attribute :name, :value
  end

  class AnonType
    attr_accessor :name, :value

    def self.find(id)
    end

    def id
      123
    end
  end

  class FriendlyAnonType < AnonType
    def self.friendly
      true
    end
  end

  controller(ApplicationController) do
    include McFastjson::FastjsonCompanion

    def current_user
    end

    helper_method :current_user

    def default_scope
      AnonType
    end

    def resource_type
      AnonType
    end

    def serializer_type
      AnonSerializer
    end
  end

  # it 'returns true' do
  #   expect(true).to eq(true)
  # end

  # Unit test individual methods
  describe 'private methods' do
    let(:params) { {} }
    let!(:request_options) { controller.send(:request_options) }

    before do
      allow(controller).to receive(:params).and_return(params)
    end

    describe 'request_options' do
      it 'creates a default hash' do
        expect(request_options).to eq({params: {}})
      end
    end

    describe 'parse_sort_param' do
      let(:params) { { sort: "attr1,-attr2" } }

      it 'sets the request_options' do
        controller.send(:parse_sort_param)
        expect(request_options[:sorting]).to eq(['attr1', 'attr2 DESC'])
      end
    end

    describe 'parse_include_param' do
      let(:params) { { include: "test1,test2.test3" } }

      it 'sets the request_options' do
        controller.send(:parse_include_param)
        expect(request_options[:include]).to eq(['test1', 'test2.test3'])
        expect(request_options[:params][:include]).to eq(['test1', 'test2.test3'])
      end
    end

    describe 'parse_active_record_includes' do
      it 'converts two arguments' do
        expect(
          controller.send(:parse_active_record_includes, ['test1', 'test2'])
        ).to eq(["test1", "test2"])
      end

      it 'converts dot notation' do
        expect(
          controller.send(:parse_active_record_includes, ['test1.test2.test3'])
        ).to eq([{"test1" => [{"test2" => ["test3"]}]}])
      end

      it 'converts root object with multiple attributes' do
        expect(
          controller.send(:parse_active_record_includes, ['test1.test2', 'test1.test3'])
        ).to eq([{"test1" => ["test2", "test3"]}])
      end

      it 'converts root object with deeper nesting' do
        expect(
          controller.send(:parse_active_record_includes, ['test1.test2.test3', 'test1.test2.test4'])
        ).to eq([{"test1" => [{"test2" => ["test3", "test4"]}]}])
      end
    end

    describe 'load_resource' do
      let(:params) { {id: 123} }

      context 'with no friendly id' do
        it 'finds the resource by id' do
          expect(controller.default_scope).to receive(:find).with(123)
          controller.send(:load_resource)
        end
      end

      context 'with friendly id' do
        it 'finds the resource by slug' do
          allow(controller).to receive(:resource_type).and_return(FriendlyAnonType)
          allow(controller).to receive(:default_scope).and_return(FriendlyAnonType)
          friendly_finder = double("friendly finder")
          expect(friendly_finder).to receive(:find).with(123)
          expect(controller.default_scope).to receive(:friendly).and_return(friendly_finder)
          controller.send(:load_resource)
        end
      end
    end

    describe 'load_resource_collection' do
      let(:default_scope) { double("default scope") }

      before do
        expect(controller).to receive(:default_scope).and_return(default_scope)
      end

      it 'assigns the default_scope' do
        controller.send(:load_resource_collection)
        expect(assigns(:resource_collection)).to eq(default_scope)
      end

      context 'with include param' do
        it 'includes the association when permitted' do
          expect_any_instance_of(AnonTypePolicy).to receive(:permitted_include_params).and_return(["assoc"])
          expect(controller).to receive(:request_options).and_return({include: ["assoc"]}).at_least(:once)
          expect(default_scope).to receive(:includes).with(["assoc"])
          controller.send(:load_resource_collection)
        end

        it 'raises an exception when not permitted' do
          expect(controller).to receive(:request_options).and_return({include: ["assoc"]}).at_least(:once)
          expect {
            controller.send(:load_resource_collection)
          }.to raise_error(ActionController::UnpermittedParameters, "found unpermitted parameter: :include=assoc")
        end
      end

      context 'with filter param' do
        let(:params) { { filter: "some-scope" } }

        it 'raises an exception when the filter_resources method is undefined' do
          expect(controller.respond_to?(:filter_resources, true)).to be_falsey
          expect {
            controller.send(:load_resource_collection)
          }.to raise_error(ActionController::UnpermittedParameters, "found unpermitted parameter: :filter=some-scope")
        end

        it 'calls filter_resources when the method is defined' do
          mock_obj = instance_double('filtered object')
          expect(mock_obj).to receive(:filtered)
          controller.send(:define_singleton_method, :filter_resources) do
            mock_obj.filtered
          end
          expect(controller.respond_to?(:filter_resources, true)).to be_truthy
          controller.send(:load_resource_collection)
        end
      end

      context 'with sort param' do
        it 'includes the association' do
          expect(controller).to receive(:request_options).and_return({sorting: ["attr DESC"]}).at_least(:once)
          expect(default_scope).to receive(:order).with(["attr DESC"])
          controller.send(:load_resource_collection)
        end
      end

      context 'with page limit' do
        let(:params) { { page: { limit: 10 } } }

        it 'limits the results' do
          expect(default_scope).to receive(:limit).with(10)
          controller.send(:load_resource_collection)
        end
      end

      context 'without page param' do
        let(:params) { { include: "some" } }

        it 'does not limit collection' do
          expect(default_scope).not_to receive(:limit)
          controller.send(:load_resource_collection)
        end
      end

      describe 'offset pagination' do
        let(:params) { { page: { limit: 50, offset: 150 } } }

        it 'applies the offset' do
          expect(default_scope).to receive(:limit).with(50).and_return(default_scope)
          expect(default_scope).to receive(:offset).with(150)
          controller.send(:load_resource_collection)
        end
      end
    end
  end
end
