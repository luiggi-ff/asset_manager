class CreateResources < ActiveRecord::Migration
  def up
    create_table :resources do |t|
      t.string :name
      t.text :description
      t.timestamps
    end
    Resource.create(name: "Computadora", description: "Notebook con 4GB de RAM y 256 GB de espacio en disco con Linux")
    Resource.create(name: "Monitor", description: "Monitor de 24 pulgadas SAMSUNG")
    Resource.create(name: "Sala de reuniones", description: "Sala de reuniones con máquinas y proyector")
  end   
  def down
    drop_table :resources
  end
end
