class ContestsController < ApplicationController
  def index
    @contests = Contest.all
  end
  
  def show
    @contest = Contest.find(params[:id])
  end
  
  def new
    @contest = Contest.new
  end
  
  def create
    @contest = Contest.new(params[:contest])
    if @contest.save
      flash[:notice] = "Successfully created contest"
      redirect_to @contest
    else
      render :action => new
    end
  end
  
  def edit
    @contest = Contest.find(params[:id])
  end
  
  def update
    @contest = Contest.find(params[:id])
  end
  
  def destroy
    @contest = Contest.find(params[:id])
    @contest.destroy
    flash[:notice] = "Successfully destroyed contest"
    redirect_to contest_url
  end
      
end
