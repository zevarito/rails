require 'active_support/core_ext/object/blank'

module ActiveRecord
  module SpawnMethods
    def merge(r)
      merged_relation = clone
      return merged_relation unless r
      return to_a & r if r.is_a?(Array)

      Relation::ASSOCIATION_METHODS.each do |method|
        value = r.send(:"#{method}_values")

        unless value.empty?
          if method == :includes
            merged_relation = merged_relation.includes(value)
          else
            merged_relation.send(:"#{method}_values=", value)
          end
        end
      end

      (Relation::MULTI_VALUE_METHODS - [:joins, :where]).each do |method|
        value = r.send(:"#{method}_values")
        merged_relation.send(:"#{method}_values=", merged_relation.send(:"#{method}_values") + value) if value.present?
      end

      merged_relation = merged_relation.joins(r.joins_values)

      merged_wheres = @where_values

      r.where_values.each do |w|
        if w.respond_to?(:operator) && w.operator == :==
          merged_wheres = merged_wheres.reject {|p| p.respond_to?(:operator) && p.operator == :== && p.operand1.name == w.operand1.name }
        end

        merged_wheres += [w]
      end

      merged_relation.where_values = merged_wheres

      Relation::SINGLE_VALUE_METHODS.reject {|m| m == :lock}.each do |method|
        value = r.send(:"#{method}_value")
        merged_relation.send(:"#{method}_value=", value) unless value.nil?
      end

      merged_relation.lock_value = r.lock_value unless merged_relation.lock_value

      # Apply scope extension modules
      merged_relation.send :apply_modules, r.extensions

      merged_relation
    end

    alias :& :merge

    def except(*skips)
      result = self.class.new(@klass, table)

      ((Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS) - skips).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values"))
      end

      (Relation::SINGLE_VALUE_METHODS - skips).each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value"))
      end

      result
    end

    def only(*onlies)
      result = self.class.new(@klass, table)

      ((Relation::ASSOCIATION_METHODS + Relation::MULTI_VALUE_METHODS) & onlies).each do |method|
        result.send(:"#{method}_values=", send(:"#{method}_values"))
      end

      (Relation::SINGLE_VALUE_METHODS & onlies).each do |method|
        result.send(:"#{method}_value=", send(:"#{method}_value"))
      end

      result
    end

    VALID_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset, :extend,
                           :order, :select, :readonly, :group, :having, :from, :lock ]

    def apply_finder_options(options)
      relation = clone
      return relation unless options

      options.assert_valid_keys(VALID_FIND_OPTIONS)
      finders = options.dup
      finders.delete_if { |key, value| value.nil? }

      ([:joins, :select, :group, :order, :having, :limit, :offset, :from, :lock, :readonly] & finders.keys).each do |finder|
        relation = relation.send(finder, finders[finder])
      end

      relation = relation.where(finders[:conditions]) if options.has_key?(:conditions)
      relation = relation.includes(finders[:include]) if options.has_key?(:include)
      relation = relation.extending(finders[:extend]) if options.has_key?(:extend)

      relation
    end

  end
end
