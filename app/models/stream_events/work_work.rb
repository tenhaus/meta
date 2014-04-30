module StreamEvents
  #THIS IS FOR GITHUB COMMITS
  class WorkWork < StreamEvent

    def work 
      subject
    end
    
    def votable?
      true
    end
    
    def work?
      true
    end
    
    def comment
      subject.metadata['message']
    end

    def commit_reference
      subject.url.split(/\//).last[0...7]
    end
        
    def title_html
      html =<<-HTML
        pushed a new commit 
        <a href="#{subject.url}">#{commit_reference}</a>
      HTML
      if comment.present?
        html << "<div class='commit-message'>#{comment}</div>"
      end
      html
    end
  end
end