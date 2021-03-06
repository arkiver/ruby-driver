# encoding: utf-8

#--
# Copyright 2013-2014 DataStax, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++

module Cassandra
  module Client
    # @private
    class RequestRunner
      def execute(connection, request, timeout=nil, raw_metadata=nil)
        connection.send_request(request, timeout).map do |response|
          case response
          when Protocol::RawRowsResultResponse
            LazyQueryResult.new(raw_metadata, response, response.trace_id, response.paging_state)
          when Protocol::RowsResultResponse
            QueryResult.new(response.metadata, response.rows, response.trace_id, response.paging_state)
          when Protocol::VoidResultResponse
            response.trace_id ? VoidResult.new(response.trace_id) : VoidResult::INSTANCE
          when Protocol::ErrorResponse
            cql = request.is_a?(Protocol::QueryRequest) ? request.cql : nil
            raise response.to_error(cql)
          when Protocol::SetKeyspaceResultResponse
            KeyspaceChanged.new(response.keyspace)
          when Protocol::AuthenticateResponse
            AuthenticationRequired.new(response.authentication_class)
          when Protocol::SupportedResponse
            response.options
          else
            if block_given?
              yield response
            else
              nil
            end
          end
        end
      end
    end

    # @private
    class AuthenticationRequired
      attr_reader :authentication_class

      def initialize(authentication_class)
        @authentication_class = authentication_class
      end
    end

    # @private
    class KeyspaceChanged
      attr_reader :keyspace

      def initialize(keyspace)
        @keyspace = keyspace
      end
    end
  end
end
