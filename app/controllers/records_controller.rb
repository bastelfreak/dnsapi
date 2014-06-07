class RecordsController < ApplicationController
  before_action :set_record, only: [:show, :edit, :clone, :update, :delete, :destroy]

  # GET /records
  # GET /records.json
  def index
    @records = if params[:domain_id]
                 domain = Domain.find(params[:domain_id]) rescue nil
                 domain.records if domain
               else
                 Record.all
               end
  end

  # GET /records/1
  # GET /records/1.json
  def show
  end

  # GET /records/new
  def new
    @domain = Domain.find(params[:domain_id]) rescue nil
    @record = Record.new(domain: @domain)
  end

  # GET /records/1/edit
  def edit
  end

  # GET /records/1/clone
  def clone
    @record = Record.new(@record.attributes.reject {|k,v| k =~ /\A(?:id|change_date)\z/})
    render :new
  end

  # POST /records
  # POST /records.json
  def create
    @record = Record.new(record_params)

    respond_to do |format|
      if @record.save
        no_validator = @record.has_dns_validator? ? nil : t('.no_validator')
        format.html { redirect_to @record, notice: t('.success'), alert: no_validator }
        format.json { render :show, status: :created, location: @record }
      else
        format.html { render :new }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /records/1
  # PATCH/PUT /records/1.json
  def update
    respond_to do |format|
      if @record.update(record_params)
        no_validator = @record.has_dns_validator? ? nil : t('.no_validator')
        format.html { redirect_to @record, notice: t('.success'), alert: no_validator }
        format.json { render :show, status: :ok, location: @record }
      else
        format.html { render :edit }
        format.json { render json: @record.errors, status: :unprocessable_entity }
      end
    end
  end

  def delete

  end

  # DELETE /records/1
  # DELETE /records/1.json
  def destroy
    domain = @record.domain
    @record.destroy
    respond_to do |format|
      format.html { redirect_to domain }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_record
      @record = Record.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def record_params
      params.require(:record).permit(:domain_id, :name, :type, :content, :ttl, :prio, :ordername, :auth, :change_date, :disabled)
    end
end
