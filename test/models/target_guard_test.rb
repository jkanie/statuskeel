require "test_helper"

class TargetGuardTest < ActiveSupport::TestCase
  test "refuses private, loopback, link-local and reserved addresses" do
    %w[10.1.2.3 172.16.0.1 192.168.1.1 127.0.0.1 169.254.169.254 100.64.0.1 0.0.0.0 224.0.0.1
       ::1 :: fc00::1 fd12::1 fe80::1 ::ffff:127.0.0.1 ::ffff:10.0.0.1].each do |address|
      assert TargetGuard.blocked?(address), "#{address} should be blocked"
    end
  end

  test "accepts public addresses" do
    %w[93.184.215.14 8.8.8.8 203.0.113.10 2606:4700::1111].each do |address|
      assert_not TargetGuard.blocked?(address), "#{address} should be allowed"
    end
  end

  test "resolve! refuses a host name that resolves to a private address" do
    error = assert_raises(TargetGuard::Refused) { TargetGuard.resolve!("intranet.example.com") }
    assert_equal "intranet.example.com resolves to 10.0.0.5, a private or reserved address", error.message
  end

  test "resolve! refuses an IP literal without a DNS lookup" do
    assert_raises(TargetGuard::Refused) { TargetGuard.resolve!("127.0.0.1") }
  end

  test "resolve! refuses a host that does not resolve" do
    error = assert_raises(TargetGuard::Refused) { TargetGuard.resolve!("nowhere.example.com") }
    assert_equal "nowhere.example.com does not resolve", error.message
  end

  test "resolve! returns the addresses of a public host" do
    assert_equal [ "203.0.113.10" ], TargetGuard.resolve!("example.com")
  end

  test "ALLOW_PRIVATE_TARGETS lets private addresses through" do
    with_private_targets_allowed do
      assert_equal [ "10.0.0.5" ], TargetGuard.resolve!("intranet.example.com")
      assert_equal [ "127.0.0.1" ], TargetGuard.resolve!("127.0.0.1")
    end
  end
end
