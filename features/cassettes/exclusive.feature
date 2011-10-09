Feature: exclusive cassette

  VCR allows cassettes to be nested. This is particularly useful in
  a context like cucumber, where you may be using a cassette for an
  entire scenario, and also using a cassette within a particular step
  definition.

  By default, both the inner and outer cassettes are active. On each
  request, VCR will look for a matching HTTP interaction in the inner
  cassette, and it will use the outer cassette as a fall back if none
  can be found.

  If you do not want the HTTP interactions of the outer cassette considered,
  you can pass the `:exclusive` option, so that the inner cassette is
  used exclusively.

  Background:
    Given a previously recorded cassette file "cassettes/outer.yml" with:
      """
      --- 
      - !ruby/struct:VCR::HTTPInteraction 
        request: !ruby/struct:VCR::Request 
          method: :get
          uri: http://localhost:7777/outer
          body: 
          headers: 
        response: !ruby/struct:VCR::Response 
          status: !ruby/struct:VCR::ResponseStatus 
            code: 200
            message: OK
          headers: 
            Content-Length: 
            - "18"
          body: Old outer response
          http_version: "1.1"
      """
    And a previously recorded cassette file "cassettes/inner.yml" with:
      """
      --- 
      - !ruby/struct:VCR::HTTPInteraction 
        request: !ruby/struct:VCR::Request 
          method: :get
          uri: http://localhost:7777/inner
          body: 
          headers: 
        response: !ruby/struct:VCR::Response 
          status: !ruby/struct:VCR::ResponseStatus 
            code: 200
            message: OK
          headers: 
            Content-Length: 
            - "18"
          body: Old inner response
          http_version: "1.1"
      """
    And a file named "setup.rb" with:
      """ruby
      include_http_adapter_for("net/http")

      start_sinatra_app(:port => 7777) do
        get('/:path') { "New #{params[:path]} response" }
      end

      require 'vcr'

      VCR.configure do |c|
        c.hook_into :fakeweb
        c.cassette_library_dir = 'cassettes'
        c.default_cassette_options = { :record => :new_episodes }
      end
      """

  Scenario: Cassettes are not exclusive by default
    Given a file named "not_exclusive.rb" with:
      """ruby
      require 'setup'

      VCR.use_cassette('outer') do
        VCR.use_cassette('inner') do
          puts response_body_for(:get, "http://localhost:7777/outer")
          puts response_body_for(:get, "http://localhost:7777/inner")
        end
      end
      """
    When I run `ruby not_exclusive.rb`
    Then it should pass with:
      """
      Old outer response
      Old inner response
      """

  Scenario: Use an exclusive cassette
    Given a file named "exclusive.rb" with:
      """ruby
      require 'setup'

      VCR.use_cassette('outer') do
        VCR.use_cassette('inner', :exclusive => true) do
          puts response_body_for(:get, "http://localhost:7777/outer")
          puts response_body_for(:get, "http://localhost:7777/inner")
        end
      end
      """
    When I run `ruby exclusive.rb`
    Then it should pass with:
      """
      New outer response
      Old inner response
      """
    And the file "cassettes/inner.yml" should contain "body: New outer response"

