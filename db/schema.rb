ActiveRecord::Schema.define(:version => 1) do
  create_table "stories", :force => true do |t|
    t.string "title", "subtitle"
    t.string  "type"
  end

  create_table "characters", :force => true do |t|
    t.integer "story_id"
    t.string "name"
  end
end
