require 'sinatra'
require 'pg'


def db_connection
  begin
    connection = PG.connect(dbname: 'movies')

    yield(connection)

  ensure
    connection.close
  end
end

def grab_movie(filter, offset, sort)

  filter == nil ? insert = "" : insert = " WHERE movies.id = $1"

  if sort == "genre"
    order = "genres.name"
  elsif sort == "studio"
    order = "studios.name"
  elsif ["title","year","rating"].include? sort
    order = "movies." + sort
  end

  offset.class == Fixnum ? offset_to_use = offset : offset_to_use = 0

  movies_query = "SELECT movies.title AS title, movies.id AS id, movies.year AS year, movies.rating AS rating, genres.name AS genre, studios.name AS studio
                  FROM movies JOIN genres ON movies.genre_id = genres.id JOIN studios ON movies.studio_id = studios.id #{insert}
                  ORDER BY #{order}
                  LIMIT 20 OFFSET #{offset_to_use.to_s};"

  if filter != nil
    movies_list = db_connection { |c| c.exec_params( movies_query+";",[filter]) }

    actors_query = "SELECT actors.name AS actor, cast_members.character AS role, actors.id AS actor_id
                    FROM cast_members JOIN actors ON cast_members.actor_id = actors.id JOIN movies ON cast_members.movie_id = movies.id #{insert}
                    ORDER BY actors.name"

    actors_list = db_connection { |c| c.exec_params( actors_query,[filter]) }

    movies_result = [movies_list.to_a, actors_list.to_a]
  else
    movies_result = db_connection { |c| c.exec( movies_query) }
  end
end

get "/actors" do

  query = "SELECT actors.name AS name, actors.id AS id, count(*)
           FROM cast_members JOIN actors ON cast_members.actor_id = actors.id JOIN movies ON cast_members.movie_id = movies.id
           GROUP BY actors.name, actors.id;"

  @actors = (db_connection { |c| c.exec( query ) }).to_a
  erb :actors
end

get "/actors/:id" do

  @actor = (db_connection { |c| c.exec_params('SELECT name, id FROM actors WHERE id = $1',[params[:id]]) }).to_a[0]

  actors_query = "SELECT movies.title AS movie, cast_members.character AS role, movies.id AS movie_id
                  FROM cast_members JOIN actors ON cast_members.actor_id = actors.id JOIN movies ON cast_members.movie_id = movies.id WHERE actors.id = $1
                  ORDER BY movies.title;"

  @movies_list = db_connection { |c| c.exec_params( actors_query,[params[:id]]) }
  erb :actor_info
end

get "/movies" do
  params[:order] == nil ? @order = "title" : @order = params[:order]
  params[:page] == nil ? @page = 1 : @page = params[:page].to_i
  offset = (@page-1)*20

  @movies = grab_movie(nil, offset, @order).to_a

  erb :movies
end

get "/movies/:id" do
  movie_info = grab_movie(params[:id],0,"title")
  @movie =  movie_info[0][0]
  @actors_list =  movie_info[1]
  erb :movie_info
end
