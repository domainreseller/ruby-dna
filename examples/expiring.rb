# frozen_string_literal: true

# List the active domains that expire within N days (default 30). Read-only:
# the client refuses anything that would change the account.
#
#   ruby examples/expiring.rb 60
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'domainnameapi'

days = Integer(ARGV[0] || 30)
client = DomainNameApi::Client.from_env(read_only: true)

# all fetches the pages as it goes.
expiring = client.domains.all(statuses: [:active]).select do |d|
  d.remaining_days && d.remaining_days <= days
end

if expiring.empty?
  puts "No active domain expires within #{days} days."
else
  expiring.sort_by(&:remaining_days).each do |d|
    puts format('%-40<name>s %<date>s %<days>4d days', name: d.domain_name,
                                                        date: d.expiration_date&.strftime('%Y-%m-%d'),
                                                        days: d.remaining_days)
  end
end
