class CsvfilesController < InheritedResources::Base
  require 'freereg_csv_processor'
  require 'digest/md5'
def index
   if session[:userid].nil?
    redirect_to '/', notice: "You are not authorised to use these facilities"
   end
end

def new
  if session[:userid].nil?
    redirect_to '/', notice: "You are not authorised to use these facilities"
  end
  @user = UseridDetail.where(:userid => session[:userid]).first
  @first_name = session[:first_name]	
  @userid = session[:userid]	
  @csvfile  = Csvfile.new(:userid  => session[:userid])
  get_user_info_from_userid
  get_userids_and_transcribers
  @role = session[:role]
end

def create
  @user = UseridDetail.where(:userid => session[:userid]).first
  @first_name = session[:first_name]  
  @csvfile  = Csvfile.new(params[:csvfile])
  @csvfile[:freereg1_csv_file_id] = session[:freereg] 
  session[:freereg]  = nil
  session[:csvfile] = @csvfile._id
  @csvfile[:userid] = session[:userid]
  @csvfile[:userid] = params[:csvfile][:userid] unless params[:csvfile][:userid].nil?
  @csvfile.file_name = @csvfile.csvfile.identifier
  case
    when File.exists?("#{File.join(Rails.application.config.datafiles,@csvfile[:userid],@csvfile.file_name)}") &&  params[:commit] == 'Replace'
      Freereg1CsvFile.destroy_all(:userid => @csvfile[:userid], :file_name =>@csvfile.file_name)
    when File.exists?("#{File.join(Rails.application.config.datafiles,@csvfile[:userid],@csvfile.file_name)}") &&  params[:commit] == 'Upload'
      if Freereg1CsvFile.where(userid: @csvfile[:userid], file_name: @csvfile.file_name).first.nil?
        FileUtils.rm("#{File.join(Rails.application.config.datafiles,@csvfile[:userid],@csvfile.file_name)}")
      else
        flash[:notice] = 'The file already exists; if you wish to replace it use the Replace option'
        redirect_to new_manage_resource_path
        return
      end #if
  end #case
  @csvfile.save

  if @csvfile.errors.any?
    flash[:notice] = 'The upload of the file was unsuccessful'
    file_for_warning_messages = "log/freereg_messages.log"
    @@message_file = File.new(file_for_warning_messages, "a")
    @@message_file.puts " File #{@csvfile.file_name} uploaded unsuccessfully at #{Time.new} for #{@csvfile[:userid]}"
    render 'edit'
    return 
  end #errors
  @user = UseridDetail.where(:userid => session[:userid]).first
  flash[:notice] = 'The upload of the file was successful'
  file_for_warning_messages = "log/freereg_messages.log"
  @message_file = File.new(file_for_warning_messages, "a")
  @message_file.puts " File #{@csvfile.file_name} uploaded successfully at #{Time.new} for #{@csvfile[:userid]}"
  place = File.join(Rails.application.config.datafiles,@csvfile[:userid],@csvfile.file_name)
  size = (File.size("#{place}"))
  unit = 0.0002
  @processing_time = (size.to_i*unit).to_i 
  render 'process' 
end #method

def edit

  #code to move existing file to attic
  @user = UseridDetail.where(:userid => session[:userid]).first
  @first_name = session[:first_name]  
  @userid = session[:userid]  
  @csvfile  = Csvfile.new(:userid  => session[:userid])
  @file = Freereg1CsvFile.find(params[:id])
  if @file.locked_by_transcriber == 'true' ||  @file.locked_by_coordinator == 'true'
    flash[:notice] = 'The replacement of the file is not permitted as it has been locked due to on-line changes; download the updated copy and remove the lock' 
    redirect_to :back 
    return
  end
  @csvfile.file_name = @file.file_name
  @person = @file.userid
  session[:freereg]  = params[:id]
  @file = @csvfile.file_name 
  @role = session[:role]
  get_userids_and_transcribers

end

def update
  @user = UseridDetail.where(:userid => session[:userid]).first
  if params[:commit] == 'Process'
    @csvfile = Csvfile.find(session[:csvfile])
    @place  = @csvfile.file_name
    range = File.join(@csvfile[:userid] ,@csvfile.file_name)
    place = File.join(Rails.application.config.datafiles,@csvfile[:userid],@csvfile.file_name)
    size = (File.size("#{place}"))
    unit = 0.0002
    processing_time = (size.to_i*unit).to_i       
    start = Time.now
    if params[:csvfile][:process]  == "Not waiting" || processing_time > 15
      pid1 = Kernel.spawn("rake build:process_freereg1_individual_csv[#{@csvfile[:userid]},#{@csvfile.file_name}]") 
      processing_time = 3*processing_time
      flash[:notice] =  "The csv file #{@place} is being processed into the database. Check your files status after at least #{processing_time} seconds."
      @csvfile.delete
          #  Process.waitall if params[:csvfile][:process]  == 'Now'
           # endtime = Time.now - start
    else
           success = FreeregCsvProcessor.process("recreate",'create_search_records',range)
           process_time = Time.now - start
           if success
            flash[:notice] =  "The csv file #{@place} has been processed into the database."
           else
            flash[:notice] =  "The csv file #{@place} was not processed into the database."
            file = File.join(Rails.application.config.datafiles,@csvfile[:userid],@csvfile.file_name)
            if File.exists?(file)
              File.delete(file)
            end #exists
           end #if success
    end #if waiting
    @csvfile.delete
    if session[:my_own]
      redirect_to my_own_freereg1_csv_file_path
      return
    end #session
    redirect_to freereg1_csv_files_path
    return 
  end  #commit
end




def delete

  @role = session[:role]
  @csvfile  = Csvfile.new(:userid  => session[:userid])
  freefile = Freereg1CsvFile.find(params[:id])
  @csvfile.file_name = freefile.file_name
  @csvfile.freereg1_csv_file_id = freefile._id
  @csvfile.save_to_attic
  @csvfile.delete
  redirect_to my_own_freereg1_csv_file_path(:anchor =>"#{session[:freereg1_csv_file_id]}"),notice: "The csv file #{freefile.file_name} has been deleted."
end

def get_userids_and_transcribers
 @user = UseridDetail.where(:userid => session[:userid]).first
 syndicate = @user.syndicate
 syndicate = session[:syndicate] unless session[:syndicate].nil?
 @people =Array.new  
 @people <<  @person 

 case
 when @user.person_role == 'system_administrator' ||  @user.person_role == 'volunteer_coordinator' ||  @user.person_role == 'data_manager'
  @userids = UseridDetail.all.order_by(userid_lower_case: 1)
when  @user.person_role == 'country_coordinator' || @user.person_role == 'county_coordinator'  || @user.person_role == 'syndicate_coordinator' 
  @userids = UseridDetail.syndicate(syndicate).all.order_by(userid_lower_case: 1) 
else
  @userids = @user
  end #end case
  unless session[:my_own] 

    @userids.each do |ids|
      @people << ids.userid
    end
  end
  
end

def download
 @role = session[:role]
 @freereg1_csv_file = Freereg1CsvFile.find(params[:id])
 @freereg1_csv_file.backup_file
 my_file =  File.join(Rails.application.config.datafiles, @freereg1_csv_file.userid,@freereg1_csv_file.file_name)
 send_file( my_file, :filename => @freereg1_csv_file.file_name)
 @freereg1_csv_file.update_attribute(:digest, Digest::MD5.file(my_file).hexdigest)
end

end
