class UsersController < ApplicationController
  def index
    supabase_client = SupabaseClient.new
    @supabase_users = supabase_client.get_users
  end
end
