# -*- coding: UTF-8 -*-

require 'rubygems'
require 'rspec'
require 'json'

RSpec.configure do |configuration|
  configuration.before(:each) do
  end
end

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), 'gen-ruby')

require 'sparsam'
require 'user_types'
serialized =        "\x15\x14\x18\x10woohoo blackbird\x1C\x15\xC8\x01\x18\bsubdata!\x00\x1A<\x15"\
                    "\x02\x18\fid_s default\x00\x15\x04\x18\fid_s default\x00\x15\x06\x18\fid_s "\
                    "default\x00+\x02X\x02\x03one\x04\x03two,\x15\xD0\x0F\x00\x00"
serialized_binary = "\b\x00\x01\x00\x00\x00\n\v\x00\x02\x00\x00\x00\x10woohoo blackbird\f\x00"\
                    "\x03\b\x00\x01\x00\x00\x00d\v\x00\x02\x00\x00\x00\bsubdata!\x00\x0E\x00"\
                    "\x04\f\x00\x00\x00\x03\b\x00\x01\x00\x00\x00\x01\v\x00\x02\x00\x00\x00\f"\
                    "id_s default\x00\b\x00\x01\x00\x00\x00\x02\v\x00\x02\x00\x00\x00\fid_s defaul"\
                    "t\x00\b\x00\x01\x00\x00\x00\x03\v\x00\x02\x00\x00\x00\fid_s default\x00\r\x00"\
                    "\x06\b\v\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x00\x03one\x00\x00\x00\x02"\
                    "\x00\x00\x00\x03two\f\x00\b\b\x00\x01\x00\x00\x03\xE8\x00\x00"

describe 'Sparsam' do
  describe Sparsam::Serializer do
    it "respect default values" do
      subdata = US.new
      subdata.id_s.should == "id_s default"
    end

    it "can serialize structs" do
      data = SS.new
      data.id_i32 = 10
      data.id_s = "woohoo blackbird"
      subdata = US.new
      subdata.id_i32 = 100
      subdata.id_s = "subdata!"
      data.us_i = subdata
      data.us_s = Set.new
      data.us_s.add(US.new({ "id_i32" => 1 }))
      data.us_s.add(US.new({ "id_i32" => 2 }))
      data.us_s.add(US.new({ "id_i32" => 3 }))
      data.mappy = {}
      data.mappy[1] = "one"
      data.mappy[2] = "two"
      data.un_field = UN.new({ :id_i32 => 1000 })
      result = data.serialize
      Sparsam.validate(SS, data, Sparsam::RECURSIVE).should == true
      result.force_encoding("BINARY").should == serialized.force_encoding("BINARY")
    end

    it "can handle utf-8 strings" do
      data = SS.new
      data.id_s = "中国电信"
      result = data.serialize
      data2 = Sparsam::Deserializer.deserialize(SS, result)
      data2.id_s.encoding.should == data.id_s.encoding
      data2.id_s.should == data.id_s
    end

    it "can deserialize structs" do
      data = Sparsam::Deserializer.deserialize(SS, serialized)
      data.id_i32.should == 10
      data.id_s.should == "woohoo blackbird"
      data.mappy[1].should == "one"
      data.mappy[2].should == "two"
      data.us_i.id_i32.should == 100
      data.us_i.id_s.should == "subdata!"
      data.un_field.id_i32.should == 1000
      data.us_s.size.should == 3
      ids = Set.new([1, 2, 3])
      data.us_s.each do |val|
        ids.delete(val.id_i32)
        val.id_s.should == "id_s default"
      end
      ids.size.should == 0
    end

    it "can deserialize unions" do
      data = UN.new({ :id_i32 => 1000 })
      result = data.serialize
      data2 = Sparsam::Deserializer.deserialize(UN, result)
      Sparsam.validate(UN, data2, Sparsam::RECURSIVE).should == true
      data2.id_i32.should == 1000
    end

    it "can handle passing in initialization data" do
      init = { "id_i32" => 10, "id_s" => "woohoo blackbird" }
      data = SS.new(init)
      data.id_i32.should == 10
      data.id_s.should == "woohoo blackbird"
    end

    it "will throw exceptions when strict validation received a non-conforming type" do
      data = EasilyInvalid.new
      data.tail = SS.new
      expect do
        Sparsam.validate(NotSS, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.s_self = Set.new([EasilyInvalid.new, SS.new])
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.l_self = [EasilyInvalid.new, SS.new]
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.mappy1 = { SS.new => 123 }
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.mappy2 = { 123 => SS.new }
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.mappy3 = { SS.new => SS.new }
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.mappy3 = { EasilyInvalid.new => SS.new }
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.mappy3 = { SS.new => EasilyInvalid.new }
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.mappy3 = { EasilyInvalid.new => EasilyInvalid.new, SS.new => EasilyInvalid.new }
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)

      data = EasilyInvalid.new
      data.id_i32 = "I'm pretty sure this is not an I32 LOL"
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      end.to raise_error(Sparsam::TypeMismatch)
    end

    it "includes additional data in TypeMismatch errors" do
      data = EasilyInvalid.new
      data.id_i32 = "definitely a string"

      e = nil
      begin
        Sparsam.validate(EasilyInvalid, data, Sparsam::STRICT)
      rescue Sparsam::TypeMismatch => exception
        e = exception
      end

      e.struct_name.should == EasilyInvalid.name
      e.field_name.should == "id_i32"
    end

    it "works with crazy thriftness" do
      data = EasilyInvalid.new
      data.sure = [{ Set.new([1]) => { 1 => Set.new([[{ EasilyInvalid.new => "sure" }]]) } }]
      Sparsam.validate(EasilyInvalid, data, Sparsam::RECURSIVE).should == true

      data = EasilyInvalid.new
      data.sure = [{ Set.new([1]) => { 1 => Set.new([[{ EasilyInvalid.new => 123 }]]) } }]
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::RECURSIVE)
      end.to raise_error(Sparsam::TypeMismatch)
    end

    it "will throw exceptions when recursive validation is passed wrong data" do
      data = EasilyInvalid.new
      data.required_stuff = MiniRequired.new
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::RECURSIVE)
      end.to raise_error(Sparsam::MissingMandatory)

      data = EasilyInvalid.new
      data.tail = EasilyInvalid.new
      data.tail.s_self = Set.new([SS.new])
      expect do
        Sparsam.validate(EasilyInvalid, data, Sparsam::RECURSIVE)
      end.to raise_error(Sparsam::TypeMismatch)
    end

    it "will throw exceptions when passed data that doesn't match type" do
      data = SS.new
      data.id_i32 = "I am not an int"
      expect { data.serialize }.to raise_error(StandardError)
    end

    it "will validate required fields" do
      data = MiniRequired.new
      expect { data.validate }.to raise_error(Sparsam::MissingMandatory)
    end

    it "includes additional information on missing required fields in exception" do
      data = MiniRequired.new

      e = nil
      begin
        data.validate
      rescue Sparsam::MissingMandatory => exception
        e = exception
      end

      e.struct_name.should == MiniRequired.name
      e.field_name.should == "id_i32"
    end

    it "includes additional information on serializing mismatched types" do
      data = MiniRequired.new
      data.id_i32 = "not an i32"

      e = nil
      begin
        data.serialize
      rescue Sparsam::TypeMismatch => exception
        e = exception
      end
      e.message.should include("T_I32", "String")

      data = EveryType.new
      data.a_struct = EveryType.new

      e = nil
      begin
        data.serialize
      rescue Sparsam::TypeMismatch => exception
        e = exception
      end
      e.message.should include("US", "EveryType")
    end

    it "includes additional information on deserializing mismatched types" do
      data = NotSS.new
      data.id_s = "not an i32"

      serialized = data.serialize

      begin
        Sparsam::Deserializer.deserialize(SS, serialized)
      rescue Sparsam::TypeMismatch => exception
        e = exception
      end
      e.message.should include("T_I32", "T_STRING")
    end

    it "will throw errors when given junk data" do
      expect do
        Sparsam::Deserializer.deserialize(SS, "wolololololol")
      end.to raise_error(Sparsam::Exception)
    end

    it "will throw errors when deserializing data with incorrect types" do
      # SS expects field 1 to be an INT
      # this is a struct w/ field 1 as a STRING instead
      data = NotSS.new
      data.id_s = "I am not an INT"
      bad_type = data.serialize
      expect do
        Sparsam::Deserializer.deserialize(SS, bad_type)
      end.to raise_error(Sparsam::TypeMismatch)
    end

    it "can deserialize objects with fields it doesn't know about" do
      # NotSS_plus is NotSS with additional fields
      # Thrift should ignore the additional fields
      data = NotSS_plus.new
      data.id_s = "This is ok"
      data.id_s2 = "This is also ok"
      data.id_i32 = 100
      ser = data.serialize
      notss = Sparsam::Deserializer.deserialize(NotSS, ser)
      notss.id_s.should == "This is ok"
      notss.id_i32.should == 100
      Sparsam::Deserializer.deserialize(Nothing, ser)
    end

    it 'only allows one field to be set in a union' do
      expect do
        UN.new({ :id_i32 => 1000, :id_s => "woops" })
      end.to raise_error(Sparsam::UnionException)

      d = UN.new({ :id_i32 => 1000 })
      d.id_s = "woops"
      d.id_s

      expect do
        d.id_i32
      end.to raise_error(Sparsam::UnionException)

      d.instance_variables.should eq([:@setfield, :@id_s])
    end

    it 'handles empty arrays' do
      data = SS.new
      data.mappy = {}
      data.us_s = Set.new
      ser = data.serialize
      unser = Sparsam::Deserializer.deserialize(SS, ser)
      unser.mappy.size.should == 0
      unser.us_s.size.should == 0
    end

    it "can serialize structs with binary" do
      data = SS.new
      data.id_i32 = 10
      data.id_s = "woohoo blackbird"
      data.mappy = {}
      data.mappy[1] = "one"
      data.mappy[2] = "two"
      subdata = US.new
      subdata.id_i32 = 100
      subdata.id_s = "subdata!"
      data.us_i = subdata
      data.us_s = Set.new
      data.us_s.add(US.new({ "id_i32" => 1 }))
      data.us_s.add(US.new({ "id_i32" => 2 }))
      data.us_s.add(US.new({ "id_i32" => 3 }))
      data.un_field = UN.new({ :id_i32 => 1000 })
      result = data.serialize(Sparsam::BinaryProtocol)
      result.force_encoding("BINARY").should == serialized_binary.force_encoding("BINARY")
    end

    it "can deserialize structs with binary" do
      data = Sparsam::Deserializer.deserialize(SS, serialized_binary, Sparsam::BinaryProtocol)
      data.id_i32.should == 10
      data.id_s.should == "woohoo blackbird"
      data.mappy[1].should == "one"
      data.mappy[2].should == "two"
      data.mappy.size.should == 2
      data.us_i.id_i32.should == 100
      data.us_i.id_s.should == "subdata!"
      data.un_field.id_i32.should == 1000
      data.us_s.size.should == 3
      ids = Set.new([1, 2, 3])
      data.us_s.each do |val|
        ids.delete(val.id_i32)
        val.id_s.should == "id_s default"
      end
      ids.size.should == 0
    end

    it "can handle nested collections like a boss" do
      data = SS.new
      data.troll = {}
      data.troll[1] = { 2 => 3 }
      ser = data.serialize
      new_data = Sparsam::Deserializer.deserialize(SS, ser)
      new_data.troll[1][2].should == 3
    end

    it "doesn't segfault on malformed data" do
      really_bad = "\x0f\x00\x05\x0b\x00\x00\x00\x01\x00\x00\x00\x03\x00"
      expect do
        Sparsam::Deserializer.deserialize(SS, really_bad, Sparsam::BinaryProtocol)
      end.to raise_error(Sparsam::Exception)
    end

    it "handles all sorts of type issues without crashing" do
      field_map = {
        a_bool: :boolean,
        a_byte: :int,
        an_i16: :int,
        an_i32: :int,
        an_i64: :int,
        a_double: :float,
        a_binary: :string,
        a_string: :string,

        an_i64_list: :int_list,
        an_i64_set: :int_set,
        an_i64_map: :int_map,

        a_list_of_i64_maps: :int_map_list,
        a_map_of_i64_maps: :int_map_map,

        a_struct: :struct,
        a_union: :union,
      }

      scalar_values = {
        boolean: true,
        int: 42,
        float: 3.14,
        string: "Hello",
        struct: US.new(id_i32: 10),
        union: UN.new(id_s: "woo"),
        complex: Complex(1),
        rational: Rational(2, 3),
      }

      simple_collection_values = scalar_values.each_with_object({}) do |(type, val), obj|
        obj[:"#{type}_list"] = [val]
        obj[:"#{type}_set"] = Set.new([val])
        obj[:"#{type}_map"] = { val => val }
      end

      nested_collection_values =
        simple_collection_values.each_with_object({}) do |(type, val), obj|
          obj[:"#{type}_list"] = [val]
          obj[:"#{type}_set"] = Set.new([val])
          obj[:"#{type}_map"] = { val => val }
        end

      all_values = scalar_values.merge(simple_collection_values).merge(nested_collection_values)

      field_map.each do |field, type|
        all_values.each do |val_type, val|
          next if val_type == type

          s = EveryType.new
          s.send(:"#{field}=", val)

          # Validation doesn't do range checking, though serialization does
          unless val_type.to_s =~ /bigint/
            expect do
              Sparsam.validate(s.class, s, Sparsam::STRICT)
            end.to(
              raise_error(Sparsam::TypeMismatch),
              "assigning #{field} : #{type} a value of " \
              "#{val.inspect} : #{val_type} did not raise TypeMismatch"
            )
          end

          expect do
            s.serialize
          end.to(
            raise_error(Sparsam::TypeMismatch),
            "assigning #{field} : #{type} a value of " \
            "#{val.inspect} : #{val_type} did not raise TypeMismatch"
          )
        end
      end
    end

    unless RUBY_VERSION =~ /^1\.9/
      it "handles integer ranges" do
        fields = {
          a_byte: 8,
          an_i16: 16,
          an_i32: 32,
          an_i64: 64,
        }

        fields.each do |field, size|
          s = EveryType.new

          max_val = 2**(size - 1) - 1

          [max_val, ~max_val].each do |val|
            s.send(:"#{field}=", val)

            expect do
              s.serialize
            end.not_to raise_error, "#{field} of #{size} bits unable to hold #{val}"
          end

          [max_val + 1, ~(max_val + 1)].each do |val|
            s.send(:"#{field}=", val)
            expect do
              s.serialize
            end.to(
              raise_error(RangeError),
              "#{field} of #{size} bits apparently able to hold value #{val} in defiance of nature"
            )
          end
        end
      end
    end

    it 'handles recursive structs' do
      recursive_struct = RecursiveStruct.new
      recursive_struct.id = 1
      recursive_struct.self_struct = RecursiveStruct.new
      recursive_struct.self_struct.id = 2
      recursive_struct.self_list = [RecursiveStruct.new]
      recursive_struct.self_list[0].id = 3

      data = recursive_struct.serialize

      new_recursive = Sparsam::Deserializer.deserialize(RecursiveStruct, data)

      new_recursive.id.should == 1
      new_recursive.self_struct.id.should == 2
      new_recursive.self_list[0].id.should == 3
    end

    it 'handles structs with modified eigenclasses' do
      nested_struct = US.new

      class << nested_struct
        def foo
        end
      end

      data = SS.new(us_i: nested_struct)

      class << data
        def foo
        end
      end

      expect { data.serialize }.not_to raise_error
    end

    describe 'ApplicationException' do
      it 'creates exceptions that can be raised' do
        e = SimpleException.new(message: "Oops")

        e.message.should eq("Oops")

        expect { raise e }.to raise_error(SimpleException, "Oops")
      end

      it 'serializes and reads exceptions' do
        e = SimpleException.new(message: "Oops")

        data = e.serialize

        e2 = Sparsam::Deserializer.deserialize(SimpleException, data)

        e2.message.should eq("Oops")

        expect { raise e2 }.to raise_error(SimpleException, "Oops")
      end
    end
  end

  describe 'generated enum types' do
    let(:enum_module) { Magic }

    it 'includes thrift constants as top level module constants' do
      enum_module.const_defined?(:Black).should == true
      enum_module.const_defined?(:White).should == true
      enum_module.const_defined?(:Red).should == true
      enum_module.const_defined?(:Blue).should == true
      enum_module.const_defined?(:Green).should == true

      enum_module.const_get(:Black).should == 0
      enum_module.const_get(:White).should == 1
      enum_module.const_get(:Red).should == 2
      enum_module.const_get(:Blue).should == 3
      enum_module.const_get(:Green).should == 4
    end

    it 'contains a VALUE_MAP constant that maps from int value to string' do
      enum_module.const_defined?(:VALUE_MAP).should == true

      value_map = enum_module.const_get(:VALUE_MAP)

      value_map.should eql({
        0 => 'Black',
        1 => 'White',
        2 => 'Red',
        3 => 'Blue',
        4 => 'Green',
      })

      value_map[enum_module.const_get(:Black)].should == 'Black'
      value_map[enum_module.const_get(:White)].should == 'White'
      value_map[enum_module.const_get(:Red)].should == 'Red'
      value_map[enum_module.const_get(:Blue)].should == 'Blue'
      value_map[enum_module.const_get(:Green)].should == 'Green'
    end

    it 'contains an INVERTED_VALUE_MAP constant that maps from name to int value' do
      enum_module.const_defined?(:INVERTED_VALUE_MAP).should == true

      inverted_value_map = enum_module.const_get(:INVERTED_VALUE_MAP)

      inverted_value_map.should eql({
        'Black' => 0,
        'White' => 1,
        'Red' => 2,
        'Blue' => 3,
        'Green' => 4,
      })

      inverted_value_map['Black'].should == enum_module.const_get(:Black)
      inverted_value_map['White'].should == enum_module.const_get(:White)
      inverted_value_map['Red'].should == enum_module.const_get(:Red)
      inverted_value_map['Blue'].should == enum_module.const_get(:Blue)
      inverted_value_map['Green'].should == enum_module.const_get(:Green)
    end

    it 'contains a VALID_VALUES constant that is a set of all enum values' do
      enum_module.const_defined?(:VALID_VALUES).should == true

      valid_values = enum_module.const_get(:VALID_VALUES)

      valid_values.should be_a(Set)
      valid_values.should include(enum_module.const_get(:Black))
      valid_values.should include(enum_module.const_get(:White))
      valid_values.should include(enum_module.const_get(:Red))
      valid_values.should include(enum_module.const_get(:Blue))
      valid_values.should include(enum_module.const_get(:Green))
      valid_values.length.should == 5
    end
  end
end
