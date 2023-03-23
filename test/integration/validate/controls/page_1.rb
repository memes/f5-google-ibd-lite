# frozen_string_literal: true

control 'page-1' do
  title 'Verify all HTTP methods to /page-1'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Shape-Reject-Trigger' => 'true' }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-header' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-header-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept, valid reject headers'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => "#{intercept_token}0",
                                                    'X-Shape-Reject-Trigger' => 'true' }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-header' do
  title 'Verify all HTTP methods to /page-1 with valid intercept header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-header-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with valid intercept, valid reject headers'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => intercept_token,
                                                    'X-Shape-Reject-Trigger' => 'true' }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-param' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept param'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, params: { 'x_customer_intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-param-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept param, valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Shape-Reject-Trigger' => 'true' },
                         params: { 'x_customer_intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-param' do
  title 'Verify all HTTP methods to /page-1 with valid intercept param'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, params: { 'x_customer_intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-param-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with valid intercept param, valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, params: { 'x_customer_intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-header-invalid-param' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept header, invalid intercept param'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => "#{intercept_token}0" },
                         params: { 'x_customer_intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-header-invalid-param-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept header, invalid intercept param, valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => "#{intercept_token}0",
                                                    'X-Shape-Reject-Trigger' => 'true' },
                         params: { 'x_customer_intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-header-valid-param' do
  title 'Verify all HTTP methods to /page-1 with valid intercept header, valid intercept param'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => intercept_token },
                         params: { 'x_customer_intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-header-valid-param-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with valid intercept header, valid intercept param, valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => intercept_token,
                                                    'X-Shape-Reject-Trigger' => 'true' },
                         params: { 'x_customer_intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-header-invalid-param' do
  title 'Verify all HTTP methods to /page-1 with valid intercept header, invalid intercept param'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => intercept_token },
                         params: { 'x_customer_intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-valid-header-invalid-param-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with valid intercept header, invalid intercept param, valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => intercept_token,
                                                    'X-Shape-Reject-Trigger' => 'true' },
                         params: { 'x_customer_intercept' => "#{intercept_token}0" }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-header-valid-param' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept header, valid intercept param'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => "#{intercept_token}0" },
                         params: { 'x_customer_intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end

control 'page-1-intercept-invalid-header-valid-param-reject-trigger' do
  title 'Verify all HTTP methods to /page-1 with invalid intercept header, valid intercept param, valid reject header'
  impact 1.0
  url = "#{input('output_customer_url')}/page-1"
  intercept_token = input('input_intercept_token')

  %i[delete get head post put patch options].each do |method|
    describe httprb(url, method: method, headers: { 'X-Customer-Intercept' => "#{intercept_token}0",
                                                    'X-Shape-Reject-Trigger' => 'true' },
                         params: { 'x_customer_intercept' => intercept_token }) do
      its('status') { should eq 200 }
      its('body') { should cmp 'Hello from origin' } unless method == :head
      its('body') { should be_empty } if method == :head
      # Header set to confirm request reached origin should be 'true'
      its('headers.X-Customer-Origin') { should cmp 'true' }
      # Header containing customer endpoint method should match
      its('headers.X-Customer-Method') { should match(/#{method.to_s.upcase}/) }
      # Header set by SSE response after it proxies to origin should be missing
      its('headers.X-Shape-Proxied') { should be_nil }
      # Header containing SSE method should be missing
      its('headers.X-Shape-Method') { should be_nil }
      # Header nonce set by SSE on proxied requests should always be missing
      its('headers.X-Shape-Nonce') { should be_nil }
      # Header nonce set by URL map on proxied requests should always be missing
      its('headers.X-Customer-Nonce') { should be_nil }
      # Header set by URL map to confirm trigger rule should be missing
      its('headers.X-Rule-Label') { should be_nil }
    end
  end
end
