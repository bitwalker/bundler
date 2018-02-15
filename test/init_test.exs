Code.require_file("test/mix_test_helper.exs")

defmodule InitTest do
  use ExUnit.Case

  import MixTestHelper

  @fixtures_path Path.join([__DIR__, "fixtures"])
  @init_test_app_path Path.join([__DIR__, "fixtures", "init_test_app"])
  @init_test_rel_path Path.join([__DIR__, "fixtures", "init_test_app", "rel"])
  @init_test_rel_config_path Path.join([__DIR__, "fixtures", "init_test_app", "rel", "config.exs"])

  @init_test_invalid_config_template_path Path.join([__DIR__, "fixtures", "init_test_app", "init_test_config.eex"])

  describe "release.init" do
    test "creates an example rel/config.exs" do
      old_dir = File.cwd!
      File.cd!(@init_test_app_path)
      {:ok, _} = File.rm_rf(@init_test_rel_path)
      refute File.exists?(@init_test_rel_path)
      refute File.exists?(@init_test_rel_config_path)
      {:ok, _} = mix("release.init")
      assert File.exists?(@init_test_rel_path)
      assert File.exists?(@init_test_rel_config_path)
      # It would be nice to test that Mix.Releases.Config.read! succeeds here
      # to verify that the example config is valid, but the call to current_version
      # in the example config fails because the init_test_app has not been loaded
      # in this test context.
      {:ok, _} = File.rm_rf(@init_test_rel_path)
      File.cd!(old_dir)
    end

    test "creates rel/config.exs from a custom template" do
      old_dir = File.cwd!
      File.cd!(@init_test_app_path)
      {:ok, _} = File.rm_rf(@init_test_rel_path)
      refute File.exists?(@init_test_rel_path)
      refute File.exists?(@init_test_rel_config_path)
      {:ok, _} = mix("release.init", ["--template=#{@init_test_invalid_config_template_path}"])
      assert File.exists?(@init_test_rel_path)
      assert File.exists?(@init_test_rel_config_path)
      {:ok, _} = File.rm_rf(@init_test_rel_path)
      File.cd!(old_dir)
    end

    test "creates rel/config.exs with sanitized release name" do
      old_dir = File.cwd!
      init_test_app_path = Path.join([__DIR__, "fixtures", "init_test.umbrella"])
      # Rename project to include invalid character
      File.cd!(@fixtures_path)
      {:ok, _} = mix("new", ["init_test_umbrella", "--umbrella"])
      System.cmd("mv", ["init_test_umbrella", "init_test.umbrella"])
      assert File.exists?(init_test_app_path)
      # Add distillery as dependency
      File.cd!(init_test_app_path)
      body = File.read!("mix.exs")
      body_with_distillery =
        String.replace(
          body,
          "defp deps do\n    []\n  end",
          "defp deps do\n    [{:distillery, path: \"../../../.\"}]\n  end"
        )

      File.write!("mix.exs", body_with_distillery)
      # Build release
      {:ok, _} = mix("release.init")
      {:ok, _} = mix("release")
      {:ok, _} = File.rm_rf(init_test_app_path)
      File.cd!(old_dir)
    end
  end
end
