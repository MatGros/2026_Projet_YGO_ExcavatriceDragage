# CoDeSys XML import/export functionality.
from __future__ import print_function
import sys, io, os

# Set target Project to primary
proj=projects.primary

# get script's current directory
ScriptPath = os.path.dirname(os.path.realpath(__file__))

# We're interested in POU nodes, so we need the GUID of the POU objects in CoDeSys.
# This is a unique ID that identifies the POU nodes.
# Other object types have a different GUID and can be exported as well.
POUGuid = Guid("6f9dac99-8de1-4efc-8465-68ac443b7d08")

# Now we create a list that stores all POU nodes.
pous = []

# From the parent node on, we recursively move through all objects.
def CollectPous(node):
    # If GUID matches the POUGuid we add that node to the list.
    if node.type == POUGuid:
        pous.append(node)
    else:
        # For each children the CollectPous function is called again.
       for child in node.get_children(True):
            CollectPous(child)

# Create the export reporter
class Reporter(ExportReporter):
   def error(self, *args):
      system.write_message(Severity.Error, "%s" % (args,))

   def warning(self, *args):
      system.write_message(Severity.Warning, "%s" % (args,))
   
   def resolve_conflict(self, obj):
      return ConflictResolve.Copy
   
   def added(self, obj):
      print("added: ", obj)

   def replaced(self, obj):
      print("replaced: ", obj)

   def skipped(self, obj):
      print("skipped: ", obj)
      
   @property
   def aborting(self):
      return False
    
# Now we run the function above and begin to collect all the leaf nodes.
for node in proj.get_children(True):
    CollectPous(node)

# We print everything just to know what's going on.
for i in pous:
    print("found: ", i.type, i.guid, i.get_name())

    filename = "{}\{}__{}.xml".format(ScriptPath, i.get_name(), i.guid)

    # create the reporter instance.
    reporter = Reporter()
    
    # and actually export the project.
    #proj.export_xml(reporter, objects, filename)
    i.export_xml(reporter, filename, True)
    
    str = i.export_xml(reporter, None, True)
    print(str)

print ("script finished.")
