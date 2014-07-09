class Freereg1CsvEntriesController < InheritedResources::Base
   layout "places"
   require 'chapman_code'
    require 'freereg_validations'

  def index
    if session[:userid].nil?
      redirect_to '/', notice: "You are not authorised to use these facilities"
    end
    display_info
    @freereg1_csv_file = Freereg1CsvFile.find(session[:freereg1_csv_file_id])
    @freereg1_csv_entries = Freereg1CsvEntry.where(:freereg1_csv_file_id => @freereg1_csv_file_id ).order_by(file_line_number: 1).page(params[:page])
  end

  def show
    load(params[:id])
     @forenames = Array.new
     @surnames = Array.new
         @multiple_witness = @freereg1_csv_entry.multiple_witnesses.all
        
          @multiple_witness.each do |witness|
          name = witness.witness_forename
          @forenames << name
          name = witness.witness_surname
          @surnames << name
         end
  end

  def error
    session[:error_id] = params[:id]
    display_info
    error_file = @freereg1_csv_file.batch_errors.find(params[:id])
    error_file.data_line[:record_type] = error_file.record_type
    @freereg1_csv_entry = Freereg1CsvEntry.new(error_file.data_line)
    @error_line = error_file.record_number
    @error_message = error_file.error_message
    @place_names = Array.new
    Place.where(:chapman_code => session[:chapman_code], :disabled.ne => "true").all.each do |place|
     @place_names << place.place_name
    end  
    
  end

  def create
    @user = UseridDetail.where(:userid => session[:userid]).first
    @freereg1_csv_file = Freereg1CsvFile.find(session[:freereg1_csv_file_id])
    @freereg1_csv_entry = Freereg1CsvEntry.new(params[:freereg1_csv_entry])
    unless session[:error_id].nil?
     error_file = @freereg1_csv_file.batch_errors.find( session[:error_id])
     file_line_number = error_file.record_number
     line_id = error_file.data_line[:line_id]
    else
     file_line_number = @freereg1_csv_file.records.to_i + 1
     line_id = @freereg1_csv_file.userid + "." + @freereg1_csv_file.file_name.upcase + "." +  file_line_number.to_s
    end
 
     @freereg1_csv_entry.update_attributes(:line_id => line_id,:record_type  => @freereg1_csv_file.record_type, :file_line_number => file_line_number)
        #need to deal with change in place
   unless @freereg1_csv_file.place == params[:freereg1_csv_entry][:place]

 #need to think about how to do this

   end



     @freereg1_csv_file.freereg1_csv_entries << @freereg1_csv_entry
     @freereg1_csv_entry.save
    if @freereg1_csv_entry.errors.any?
      flash[:notice] = 'The creation of the record was unsuccessful'
      display_info
      render :action => 'error'
     else
      Freereg1CsvFile.backup_file(@freereg1_csv_file)
      #update file with date and lock and delete error
      @freereg1_csv_file.locked_by_transcriber = "true" if session[:my_own] == 'my_own'
      @freereg1_csv_file.locked_by_coordinator = "true" unless session[:my_own] == 'my_own'
      @freereg1_csv_file.modification_date = Time.now.strftime("%d %b %Y")
    if session[:error_id].nil?
      @freereg1_csv_file.records = @freereg1_csv_file.records.to_i + 1 
    case 
     when @freereg1_csv_file.record_type == 'ba'
      date = params[:freereg1_csv_entry][:baptism_date]
     when @freereg1_csv_file.record_type == 'ma' 
       date = params[:freereg1_csv_entry][:marriage_date]
     when @freereg1_csv_file.record_type == 'bu' 
       date = params[:freereg1_csv_entry][:burial_date]
    end
      date = FreeregValidations.year_extract(date)
    unless date.nil?
      @freereg1_csv_file.datemax = date if date > @freereg1_csv_file.datemax
      @freereg1_csv_file.datemin = date if date < @freereg1_csv_file.datemin
      xx = ((date.to_i - 1530)/10).to_i unless date.to_i <= 1530 # avoid division into zero
      @freereg1_csv_file.daterange[xx] = @freereg1_csv_file.daterange[xx] + 1 unless (xx < 0 || xx > 50)
    end
  else
     @freereg1_csv_file.error =  @freereg1_csv_file.error - 1
     @freereg1_csv_file.batch_errors.delete( @freereg1_csv_file.batch_errors.find(session[:error_id]))
   end
    session[:error_id] = nil
    @freereg1_csv_file.save
    display_info
    flash[:notice] = 'The creation/update in entry contents was successful, backup of file made and locked' 
    render :action => 'show'
    end
  else
end

def new
  session[:error_id] = nil
  display_info
  file_line_number = @freereg1_csv_file.records.to_i + 1
  line_id = @freereg1_csv_file.userid + "." + @freereg1_csv_file.file_name.upcase + "." +  file_line_number.to_s
  @freereg1_csv_entry = Freereg1CsvEntry.new(:record_type  => @freereg1_csv_file.record_type, :line_id => line_id, :file_line_number => file_line_number )
end

def edit
 
    load(params[:id])
    
end

def update
  load(params[:id])
  record_type = @freereg1_csv_file.record_type
  params[:freereg1_csv_entry][:record_type] = record_type
  @freereg1_csv_entry.update_attributes(params[:freereg1_csv_entry])
  if @freereg1_csv_entry.errors.any?
    flash[:notice] = 'The update of the record was unsuccessful'
    render :action => 'edit'
  else
    file = @freereg1_csv_file
    Freereg1CsvFile.backup_file(file)
    file.locked_by_transcriber = "true" if session[:my_own] == 'my_own'
    file.locked_by_coordinator = "true" unless session[:my_own] == 'my_own'
    file.modification_date = Time.now.strftime("%d %b %Y")
    file.save
    flash[:notice] = 'The change in entry contents was successful, backup of file made and locked' 
    render :action => 'show'
    end
  end

  def select_page
     display_info
     @max = @freereg1_csv_file.records
  end

  def selected_page
    display_info
    @number = params[:number].to_i
    @number = @freereg1_csv_file.records.to_i if @number > @freereg1_csv_file.records.to_i
    @page_number = @number/50 + 1
    params[:page] = @page_number
    @freereg1_csv_entries = Freereg1CsvEntry.where(:freereg1_csv_file_id => @freereg1_csv_file_id ).order_by(file_line_number: 1).page(params[:page])
   
  end

  def load(file_id)
    @freereg1_csv_entry = Freereg1CsvEntry.find(file_id)
    session[:freereg1_csv_entry_id] = @freereg1_csv_entry._id
    display_info
  end

def display_info
    @freereg1_csv_file = Freereg1CsvFile.find(session[:freereg1_csv_file_id])
    @freereg1_csv_file_id =  session[:freereg1_csv_file_id]
    @freereg1_csv_file_name =  session[:freereg1_csv_file_name]
    @register = @freereg1_csv_file.register
    #@register_name = @register.register_name 
    #@register_name = @register.alternate_register_name if @register_name.nil?
    @register_name = RegisterType.display_name(@register.register_type)
    @church = session[:church_id]
    @church_name = session[:church_name]
    @place = session[:place_id]
    @county =  session[:county]
    @place_name = session[:place_name] 
    @first_name = session[:first_name]
    @user = UseridDetail.where(:userid => session[:userid]).first
end
  
end
