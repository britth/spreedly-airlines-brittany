module HttpClient
  def self.make_request(request_type, url, body = nil)
    uri = URI.parse(url)

    if request_type == :get
      request = Net::HTTP::Get.new(uri)
    elsif request_type == :post
      request = Net::HTTP::Post.new(uri)
      request.body = body
    end

    request.basic_auth(ENV["SPREEDLY_ENV"], ENV["ACCESS_SECRET"])
    request.content_type = "application/json"

    req_options = {
      use_ssl: uri.scheme == "https",
    }

    Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
  end

  def self.fetch_paginated_data(path)
    Enumerator.new do |yielder|
      last_token = nil
      total_results = 0

      loop do
        results = last_token ? make_request(:get, "#{path}&since_token=#{last_token}") : make_request(:get, path)
        parsed = JSON.parse results.body
        transactions = parsed['transactions']

        # limit to last couple hundred transactions
        if transactions.count > 0 && total_results <= 100
          transactions.map { |item| yielder << item }
          last_token = transactions.last['token']
          total_results += transactions.count
        else
          raise StopIteration
        end
      end
    end.lazy
  end
end
