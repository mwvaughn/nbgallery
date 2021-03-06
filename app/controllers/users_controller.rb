# User controller
class UsersController < ApplicationController
  before_action :verify_admin, except: %i[show groups index edit update]
  before_action :set_viewed_user, except: %i[index new create]

  # GET /users
  def index
    respond_to do |format|
      format.html do
        verify_admin
        @users = User.all
      end
      format.json do
        verify_admin if params[:prefix].blank? || params[:prefix].size < 3
        @users =
          if params[:prefix].blank?
            User.all
          else
            User.where('user_name LIKE ?', "#{params[:prefix]}%")
          end
        render json: @users.pluck(:user_name).to_json
      end
    end
  end

  # GET /users/:user_name
  def show
    @notebooks = query_notebooks.where(owner: @viewed_user)
    respond_to do |format|
      format.html
      format.json {render 'notebooks/index'}
    end
  end

  # GET /users/:user_name/groups
  def groups
    @groups = @viewed_user.groups_with_notebooks
  end

  # GET /users/:user_name/detail
  def detail
    @recent_updates = @viewed_user.recent_updates.take(40)
    @recent_actions = @viewed_user.recent_actions.take(20)
    @similar_users = @viewed_user.similar_users.take(20)

    # Note: these are all filtered by the viewed user's permissions
    @recommended_notebooks = @viewed_user.notebook_recommendations.take(20)
    @recommended_groups = @viewed_user.group_recommendations.take(20)
    @recommended_tags = @viewed_user.tag_recommendations.take(20)
  end

  # GET /users/new
  def new
    @viewed_user = User.new
  end

  def edit
    # TODO: admin checkbox should not appear in the view

    raise User::Forbidden, 'you are not allowed to view this page' unless
      @user.id == @viewed_user.id || @user.admin?
  end

  # POST /users
  def create
    @viewed_user = User.new(user_params)

    respond_to do |format|
      if @viewed_user.save
        format.html {redirect_to @viewed_user, notice: 'User was successfully created.'}
        format.json {render :show, status: :created, location: @viewed_user}
      else
        format.html {render :new}
        format.json {render json: @viewed_user.errors, status: :unprocessable_entity}
      end
    end
  end

  # PATCH/PUT /users/:user_name
  def update
    raise User::Forbidden, 'you are not allowed to view this page' unless
      @user.id == @viewed_user.id || @user.admin?

    respond_to do |format|
      if @viewed_user.update(user_params)
        format.html {redirect_to @viewed_user, notice: 'User was successfully updated.'}
        format.json {render :show, status: :ok, location: @viewed_user}
      else
        format.html {render :edit}
        format.json {render json: @viewed_user.errors, status: :unprocessable_entity}
      end
    end
  end

  # DELETE /users/:user_name
  def destroy
    @viewed_user.destroy
    respond_to do |format|
      format.html {redirect_to users_url, notice: 'User was successfully destroyed.'}
      format.json {head :no_content}
    end
  end

  # GET/PATCH /users/:id/finish_signup
  def finish_signup
    # authorize! :update, @user
    return unless request.patch? && params[:user] #&& params[:user][:email]
    if @user.update(user_params)
      @user.skip_reconfirmation!
      #sign_in(@user, :bypass => true)
      redirect_to @user, notice: 'Your profile was successfully updated.'
    else
      @show_errors = true
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_viewed_user
    @viewed_user = User.find_by(user_name: params[:id]) || User.find_by(email: params[:id]) || User.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def user_params
    general_fields = %i[email user_name first_name last_name org]
    admin_fields = %i[email user_name first_name last_name org admin]
    fields = @user.admin? ? admin_fields : general_fields
    params.require(:user).permit(*fields)
  end
end
