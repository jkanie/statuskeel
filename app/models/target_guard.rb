require "ipaddr"
require "socket"

# Decides whether statuskeel may connect to a host. A hosted status page must not
# become a way to probe the network it runs in, so every address in BLOCKED_RANGES
# (private, loopback, link-local, reserved) is refused unless ALLOW_PRIVATE_TARGETS is on.
class TargetGuard
  class Refused < StandardError; end

  BLOCKED_RANGES = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.168.0.0/16 198.18.0.0/15 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8
  ].map { |range| IPAddr.new(range) }.freeze

  # Looks up the addresses of a host name. Tests replace it to stay off the network.
  cattr_accessor :resolver, default: lambda { |host|
    begin
      Addrinfo.getaddrinfo(host, nil, nil, :STREAM).map(&:ip_address).uniq
    rescue SocketError
      []
    end
  }

  class << self
    def allow_private?
      Rails.configuration.x.allow_private_targets
    end

    # Returns the addresses to connect to, or raises Refused.
    def resolve!(host)
      raise Refused, "the URL has no host" if host.blank?

      addresses = ip_literal?(host) ? [ host ] : resolver.call(host)
      raise Refused, "#{host} does not resolve" if addresses.empty?

      unless allow_private?
        if (blocked = addresses.find { |address| blocked?(address) })
          raise Refused, "#{host} resolves to #{blocked}, a private or reserved address"
        end
      end

      addresses
    end

    def blocked?(address)
      ip = IPAddr.new(address)
      ip = ip.native if ip.ipv6? && ip.ipv4_mapped?
      BLOCKED_RANGES.any? { |range| range.family == ip.family && range.include?(ip) }
    rescue IPAddr::InvalidAddressError
      true
    end

    private
      def ip_literal?(host)
        IPAddr.new(host)
        true
      rescue IPAddr::InvalidAddressError
        false
      end
  end
end
