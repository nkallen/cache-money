class Array
  alias_method :count, :size

  def to_hash
    keys_and_values_without_nils = reject { |key, value| value.nil? }
    shallow_flattened_keys_and_values_without_nils = keys_and_values_without_nils.inject([]) { |result, pair| result += pair }
    Hash[*shallow_flattened_keys_and_values_without_nils]
  end
end
