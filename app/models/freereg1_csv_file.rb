# Copyright 2012 Trustees of FreeBMD
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
class Freereg1CsvFile 
  include MongoMapper::Document
  many :freereg1_csv_entry

  # Fields correspond to cells in CSV headers  
  key :county, String 
  key :place, String 
  key :register, String 
  key :register_type, String
  key :record_type, String
  key :records, String
  key :datemin, String
  key :datemax, String
  key :daterange, Array
  key :userid, String
  key :file_name, String
  key :transcriber_name, String
  key :transcriber_email, String
  key :transcriber_syndicate, String
  key :credit_email, String
  key :credit_name, String
  key :first_comment, String
  key :second_comment, String
  key :transcription_date, String
  key :modification_date, String
  key :lds, String
  key :characterset, String
  timestamps!
end
