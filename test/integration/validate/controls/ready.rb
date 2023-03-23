# frozen_string_literal: true

# require 'http'
control 'customer' do
  title 'Verify Customer endpoint is ready'
  impact 1.0
  url = "#{input('output_customer_url')}/readyz"

  describe httprb(url) do
    its('status') { should eq 200 }
    its('body') { should cmp 'customer-ready' }
  end
end

control 'sse' do
  title 'Verify SSE endpoint is ready'
  impact 1.0
  url = "#{input('output_sse_url')}/readyz"

  describe httprb(url) do
    its('status') { should eq 200 }
    its('body') { should cmp 'sse-ready' }
  end
end
