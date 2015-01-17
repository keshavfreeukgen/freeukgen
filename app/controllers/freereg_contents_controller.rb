class FreeregContentsController < ApplicationController
  require 'chapman_code'
  require 'freereg_options_constants'
  skip_before_filter :require_login

  def index
    redirect_to :action => :new
  end

  def new
    @freereg_content = FreeregContent.new 
    @options = ChapmanCode.add_parenthetical_codes(ChapmanCode.remove_codes(ChapmanCode::CODES))
  end

  def create 
    @freereg_content = FreeregContent.new(params[:freereg_content].delete_if{|k,v| v.blank? })
    @county = params[:freereg_content][:chapman_codes]
    place = params[:freereg_content][:place_ids]
    if  @freereg_content.save
      @county = ChapmanCode.name_from_code(@county[0])
      session[:county] = @county
      session[:county_id] = nil
      redirect_to show_place_path(place)
      return
    else
      @freereg_content.chapman_codes = []
      @options = ChapmanCode.add_parenthetical_codes(ChapmanCode.remove_codes(ChapmanCode::CODES))
      render :new
    end
  end


  def show
    if @page = Refinery::Page.where(:slug => 'dap-place-index-text').exists?
      @page = Refinery::Page.where(:slug => 'dap-place-index-text').first.parts.first.body.html_safe
    else
      @page = ""
    end
    @county = session[:county]
    @chapman_code = ChapmanCode.values_at( @county)
    @places = Places.where(:data_present => true).all.order_by(place_name: 1).page(page) if @county == 'all'
    @places = Place.where(:chapman_code => @chapman_code, :data_present => true).all.order_by(place_name: 1).page(params[:page])  unless @county == 'all'
    session[:page] = request.original_url
    session[:county_id]  = params[:id]
  end

  def show_place
    @place = Place.find(params[:id])
    @county =  @place.county
    @country = @place.country
    @place_name = @place.place_name
    @names = @place.get_alternate_place_names
    @stats = @place.data_contents   
    @county_id =  session[:county_id]
    session[:place] = @place_name
    session[:place_id] = @place._id
  end

  def show_church
    if @page = Refinery::Page.where(:slug => 'dap-place-index-text').exists?
      @page = Refinery::Page.where(:slug => 'dap-place-index-text').first.parts.first.body.html_safe
    else
      @page = ""
    end

    @church = Church.find(params[:id])
    @stats = @church.data_contents 
    @place_name = @church.place.place_name
    @place = @church.place
    @county = @place.county
    @church_name = @church.church_name
    @county_id =  session[:county_id]
    @registers = Register.where(:church_id => params[:id]).order_by(:record_types.asc, :register_type.asc, :start_year.asc).all
  end

  def show_register
    if @page = Refinery::Page.where(:slug => 'register-sidebar-text').exists?
      @page = Refinery::Page.where(:slug => 'register-sidebar-text').first.parts.first.body.html_safe
    else
      @page = ""
    end

    @register = Register.find(params[:id])
    @church  = @register.church
    @place = @church.place
    @county = @place.county
    @files_id = Array.new
    @place_name = @place.place_name
    @county_id =  session[:county_id]
    session[:register_id] = params[:id]
    @register_name = @register.register_name 
    @register_name = @register.alternate_register_name if @register_name.nil?
    session[:register_name] = @register_name
    @church = @church.church_name
    individual_files = Freereg1CsvFile.where(:register_id =>params[:id]).order_by(:record_types.asc, :start_year.asc).all
    @files = Freereg1CsvFile.combine_files(individual_files)
    session[:county] = @county
    session[:church_name] = @church
    session[:place_name] = @place_name
    session[:place_id] = @place._id
  end

  def show_decade
    @register = Register.find(session[:register_id])
    @files_id = session[:files]
    @register_id = session[:register_id]
    @register_name = session[:register_name]
    @county_id = session[:county_id]
    individual_files = Freereg1CsvFile.where(:register_id => @register_id).order_by(:record_types.asc, :start_year.asc).all
    @files = Freereg1CsvFile.combine_files(individual_files)
    @decade = { }
    @files.each do |my_file|
      @decade[my_file.record_type] = my_file.daterange
    end
    max = @decade.first[1].length
    @decade["ba"] = Array.new(max, 0) unless @decade["ba"]
    @decade["bu"] = Array.new(max, 0) unless @decade["bu"]
    @decade["ma"] = Array.new(max, 0) unless @decade["ma"]

    @record_type = params[:id]
    @place = Place.find(session[:place_id])
    @church = session[:church_name]
    @place_name = session[:place_name]
    @county = session[:county]
    @RType = RegisterType.display_name(@register.register_type)
  end

  def remove_countries_from_parenthetical_codes
  end

end
