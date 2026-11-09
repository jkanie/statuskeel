require "test_helper"
require "capybara/cuprite"

# System tests drive headless Chrome over the DevTools protocol with Cuprite (no chromedriver).
# Ferrum finds Chrome on the PATH, or set BROWSER_PATH to the browser binary.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, screen_size: [ 1280, 900 ], options: {
    headless: true,
    js_errors: true,
    process_timeout: 30,
    timeout: 10,
    # Chrome refuses its sandbox as root (containers) and on some CI runners.
    dockerize: ENV["CI"].present? || Process.uid.zero?
  }
end
