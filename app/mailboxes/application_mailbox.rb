class ApplicationMailbox < ActionMailbox::Base
  # incidents@<domain> opens an incident, incident+<id>@<domain> adds an update to incident <id>.
  INCIDENTS_ADDRESS = /\Aincidents?(?:\+(\d+))?@/i

  routing INCIDENTS_ADDRESS => :incidents
end
