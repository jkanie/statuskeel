require "test_helper"
require "rake"

class AdminTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:create")
    Rake::Task["admin:create"].reenable
  end

  def run_task(env)
    previous = env.keys.index_with { |key| ENV[key] }
    env.each { |key, value| ENV[key] = value }
    capture_io { Rake::Task["admin:create"].invoke }
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  test "creates an admin from ADMIN_EMAIL and ADMIN_PASSWORD" do
    out, = run_task("ADMIN_EMAIL" => "Ops@Example.com", "ADMIN_PASSWORD" => "correct horse battery")

    assert_equal "Created admin ops@example.com.\n", out
    assert User.authenticate_by(email_address: "ops@example.com", password: "correct horse battery")
  end

  test "resets the password of an existing admin" do
    out, = run_task("ADMIN_EMAIL" => "one@example.com", "ADMIN_PASSWORD" => "a much longer password")

    assert_equal "Updated admin one@example.com.\n", out
    assert User.authenticate_by(email_address: "one@example.com", password: "a much longer password")
  end
end
