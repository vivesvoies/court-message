class UpdateMessageStatusEnum < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
      ALTER TYPE message_status ADD VALUE 'expired';
      ALTER TYPE message_status ADD VALUE 'failed';
      ALTER TYPE message_status ADD VALUE 'deleted';
    SQL
  end

  def down
    execute <<-SQL
      ALTER TYPE message_status DROP VALUE 'expired';
      ALTER TYPE message_status DROP VALUE 'failed';
      ALTER TYPE message_status DROP VALUE 'deleted';
    SQL
  end
end
