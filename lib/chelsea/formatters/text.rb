#
# Copyright 2019-Present Sonatype Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'pastel'
require 'tty-table'
require_relative 'formatter'

module Chelsea
  class TextFormatter < Formatter
    def initialize(quiet: false)
      @quiet = quiet
      @pastel = Pastel.new
    end

    def get_results(server_response, reverse_dependencies)
      response = String.new
      if !@quiet
        response += "\n"\
        "Audit Results\n"\
        "=============\n"
      end

      i = 0
      vuln_count = 0
      count = server_response.count()
      server_response.sort! {|x| x['vulnerabilities'].count}

      server_response.each do |r|
        i += 1
        package = r['coordinates']
        vulnerable = r['vulnerabilities'].length.positive?
        coord = r['coordinates'].sub('pkg:gem/', '')
        name = coord.split('@')[0]
        version = coord.split('@')[1]
        reverse_deps = reverse_dependencies["#{name}-#{version}"]
        if vulnerable
          vuln_count += 1
          response += @pastel.red("[#{i}/#{count}] - #{package} ") + @pastel.red.bold("Vulnerable.\n")
          response += _get_reverse_deps(reverse_deps, name) if reverse_deps
          r['vulnerabilities'].each do |k, _|
            response += _format_vuln(k)
          end
        else
          if !@quiet
            response += @pastel.white("[#{i}/#{count}] - #{package} ") + @pastel.green.bold("No vulnerabilities found!\n")
            response += _get_reverse_deps(reverse_deps, name) if reverse_deps
          end
        end
      end

      table = TTY::Table.new ['Dependencies Audited', 'Vulnerable Dependencies'], [[count,vuln_count]]
      response += table.render(:unicode)
      response
    end

    def do_print(results)
      puts results
    end

    def _format_vuln(vuln)
      cvssScore = vuln['cvssScore']
      vuln_response = "\n\tVulnerability Details:\n"
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tID: #{vuln['id']}\n")
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tTitle: #{vuln['title']}\n")
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tDescription: #{vuln['description']}\n")
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tCVSS Score: #{vuln['cvssScore']}\n")
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tCVSS Vector: #{vuln['cvssVector']}\n")
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tCVE: #{vuln['cve']}\n")
      vuln_response += _color_based_on_cvss_score(cvssScore, "\n\tReference: #{vuln['reference']}\n\n")
      vuln_response
    end

    def _color_based_on_cvss_score(cvssScore, text)
      case cvssScore
      when 0..3
        @pastel.cyan.bold(text)    
      when 4..5
        @pastel.yellow.bold(text)
      when 6..7
        @pastel.orange.bold(text)
      else
        @pastel.red.bold(text)
      end
    end

    def _get_reverse_deps(coords, name)
      coords.each_with_object(String.new) do |dep, s|
        dep.each do |gran|
          if gran.class == String && !gran.include?(name)
            s << "\tRequired by: #{gran}\n"
          end
        end
      end
    end
  end
end
