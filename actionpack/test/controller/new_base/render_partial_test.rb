require 'abstract_unit'

module RenderPartial

  class BasicController < ActionController::Base

    self.view_paths = [ActionView::FixtureResolver.new(
      "render_partial/basic/_basic.html.erb"     => "BasicPartial!",
      "render_partial/basic/basic.html.erb"      => "<%= @test_unchanged = 'goodbye' %><%= render :partial => 'basic' %><%= @test_unchanged %>",
      "render_partial/basic/with_json.html.erb"  => "<%= render 'with_json.json' %>",
      "render_partial/basic/_with_json.json.erb" => "<%= render 'final' %>",
      "render_partial/basic/_final.json.erb"     => "{ final: json }"
    )]

    def html_with_json_inside_json
      render :action => "with_json"
    end

    def changing
      @test_unchanged = 'hello'
      render :action => "basic"
    end
  end

  class TestPartial < Rack::TestCase
    testing BasicController

    test "rendering a partial in ActionView doesn't pull the ivars again from the controller" do
      get :changing
      assert_response("goodbyeBasicPartial!goodbye")
    end

    test "rendering a template with renders another partial with other format that renders other partial in the same format" do
      get :html_with_json_inside_json
      assert_content_type "text/html; charset=utf-8"
      assert_response "{ final: json }"
    end
  end

end
