class AddChannelToVideos < ActiveRecord::Migration[7.2]
  def change
    add_column :videos, :channel, :string
  end
end
