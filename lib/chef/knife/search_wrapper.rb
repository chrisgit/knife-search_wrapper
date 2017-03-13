# Ripped from Chef::Knife::Search see Readme.MD
require 'chef/knife'
require 'chef/knife/core/node_presenter'
require 'addressable/uri'

class Chef
  class Knife
    class SearchWrapper < Knife

      include Knife::Core::MultiAttributeReturnOption

      deps do
        require 'chef/node'
        require 'chef/environment'
        require 'chef/api_client'
        require 'chef/search/query'
      end

      include Knife::Core::NodeFormattingOptions

      banner 'knife search INDEX QUERY (options)'

      option :sort,
        :short => '-o SORT',
        :long => '--sort SORT',
        :description => 'The order to sort the results in',
        :default => nil

      option :start,
        :short => '-b ROW',
        :long => '--start ROW',
        :description => 'The row to start returning results at',
        :default => 0,
        :proc => lambda { |i| i.to_i }

      option :rows,
        :short => '-R INT',
        :long => '--rows INT',
        :description => 'The number of rows to return',
        :default => nil,
        :proc => lambda { |i| i.to_i }

      option :run_list,
        :short => '-r',
        :long => '--run-list',
        :description => 'Show only the run list'

      option :id_only,
        :short => '-i',
        :long => '--id-only',
        :description => 'Show only the ID of matching objects'

      option :query,
        :short => '-q QUERY',
        :long => '--query QUERY',
        :description => 'The search query; useful to protect queries starting with -'

      option :filter_result,
        :short => '-f FILTER',
        :long => '--filter-result FILTER',
        :description => 'Only return specific attributes of the matching objects; for example: "ServerName=name, Kernel=kernel.version"'

      def run
        init_variables
        if config[:sort]
          @sort_key = config[:sort]
          @sort_path = @sort_key.split('.')
        end
        read_cli_args
        fuzzify_query
        search_data

        if @type == 'node'
          ui.use_presenter Knife::Core::NodePresenter
        end
        # json and yaml
        if ui.interchange?
          output({ :results => @item_count, :rows => @items })
        else
          # summary, text, pp
          @sort_items.sort_by! {|item| item[:key] } if config[:sort]
          ui.log "#{@item_count} items found"
          ui.log("\n")
          @sort_items.each do |sorted_item|
            item = @items[sorted_item[:index]]
            output(item)
            unless config[:id_only]
              ui.msg("\n")
            end
          end
        end
      end

      private

      def init_variables
        @items = []
        @item_count = 0
        @current_item = nil
        @current_item_hash = nil
        @sort_items = []
        @sort_key = ''
        @sort_path = ''
      end

      def search_data
        q = Chef::Search::Query.new
        escaped_query = Addressable::URI.encode_component(@query, Addressable::URI::CharacterClasses::QUERY)

        search_args = Hash.new
        search_args[:sort] = config[:sort] if config[:sort]
        search_args[:start] = config[:start] if config[:start]
        search_args[:rows] = config[:rows] if config[:rows]
        if config[:filter_result]
          search_args[:filter_result] = create_result_filter(config[:filter_result])
        elsif (not ui.config[:attribute].nil?) && (not ui.config[:attribute].empty?)
          search_args[:filter_result] = create_result_filter_from_attributes(ui.config[:attribute])
        end

        begin
          q.search(@type, escaped_query, search_args) do |item|
            formatted_item = Hash.new
            if item.is_a?(Hash)
              # doing a little magic here to set the correct name
              formatted_item[item["__display_name"]] = item.reject { |k| k == "__display_name" }
            else
              formatted_item = format_for_display(item)
            end
            @current_item = item
            @sort_items << sort_data
            @items << formatted_item
            @item_count = @item_count + 1
          end
        rescue Net::HTTPServerException => e
          msg = Chef::JSONCompat.from_json(e.response.body)["error"].first
          ui.error("knife search failed: #{msg}")
          exit 1
        end
      end

      def read_cli_args
        if config[:query]
          if @name_args[1]
            ui.error "Please specify query as an argument or an option via -q, not both"
            ui.msg opt_parser
            exit 1
          end
          @type = name_args[0]
          @query = config[:query]
        else
          case name_args.size
          when 0
            ui.error "No query specified"
            ui.msg opt_parser
            exit 1
          when 1
            @type = "node"
            @query = name_args[0]
          when 2
            @type = name_args[0]
            @query = name_args[1]
          end
        end
      end

      def fuzzify_query
        if @query !~ /:/
          @query = "tags:*#{@query}* OR roles:*#{@query}* OR fqdn:*#{@query}* OR addresses:*#{@query}* OR policy_name:*#{@query}* OR policy_group:*#{@query}*"
        end
      end

      # This method turns a set of key value pairs in a string into the appropriate data structure that the
      # chef-server search api is expecting.
      # expected input is in the form of:
      # -f "return_var1=path.to.attribute, return_var2=shorter.path"
      #
      # a more concrete example might be:
      # -f "env=chef_environment, ruby_platform=languages.ruby.platform"
      #
      # The end result is a hash where the key is a symbol in the hash (the return variable)
      # and the path is an array with the path elements as strings (in order)
      # See lib/chef/search/query.rb for more examples of this.
      def create_result_filter(filter_string)
        final_filter = Hash.new
        filter_string.delete!(" ")
        filters = filter_string.split(",")
        filters.each do |f|
          return_id, attr_path = f.split("=")
          final_filter[return_id.to_sym] = attr_path.split(".")
        end
        return final_filter
      end

      def create_result_filter_from_attributes(filter_array)
        final_filter = Hash.new
        filter_array.each do |f|
          final_filter[f] = f.split(".")
        end
        # adding magic filter so we can actually pull the name as before
        final_filter["__display_name"] = [ "name" ]
        return final_filter
      end

      def sort_data()
        return { index: @item_count, key: '' } unless config[:sort]
        sort_value = ''
        if @current_item.is_a?(Hash)
          sort_value = hash_value_for_key(@current_item, @sort_key)
        else
          if @current_item.respond_to?(@sort_key.to_sym)
            sort_value = @current_item.send(@sort_key.to_sym)
          elsif
            @current_item_hash = @current_item.to_hash # Also to_hash which has slightly different results
            sort_value = @current_item_hash.dig(*@sort_path) || dig_top_level_keys() || ''
          end
        end
        { index: @item_count, key: sort_value }
      end

    # To match dot path keys
      def hash_value_for_key(hsh, key)
        if hsh.has_key?(key)
          matched = hsh[key] || ''
        else
          hsh.keys.each do |sub_key|
            sub_key_value = hsh[sub_key]
            matched = hash_value_for_key(sub_key_value, key) if sub_key_value.is_a?(Hash)
            break if matched
          end
        end
        matched
      end

    # To match Chef:: objects that have been converted to hash_value_for_key
      def dig_top_level_keys()
        sort_value = nil
        @current_item_hash.keys.each do |key|
          if @current_item_hash[key].is_a?(Hash)
            sort_value = @current_item_hash[key].dig(*@sort_path)
            break if sort_value
          end
        end
        sort_value
      end
    end
  end
end
