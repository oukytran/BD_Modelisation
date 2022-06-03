-- TANG Kevin p1501263
-- TRAN David p1911682
-- TP Note BDW2 2022


/************************** Question 1 *********************************/
drop table Emprunt;
drop table Livre;
drop table Personne;


CREATE TABLE Personne (
	idP integer primary key,
	nom varchar(30) not null,
	prenom varchar(30) not null,
	adresse varchar(30) not null,
	
	credits integer not null
);

CREATE TABLE Livre (
 	id_isbn integer primary key,
  	titre varchar(30) not null,
	type_livre varchar(30) not null,
	nb_pages integer not null,
	  
	--Preteur
	date_pret timestamp not null,
	id_preteur int not null,
	  
	foreign key (id_preteur) references Personne on delete cascade,
	  
	constraint pret_unique unique (id_preteur, date_pret),
	
	constraint preteur_unique unique (id_isbn, id_preteur)
	
);

create table Emprunt (
	id_emprunteur integer not null,
	date_emprunt date not null,
	isbn integer not null,
	
	--Emprunteur
	foreign key (id_emprunteur) references Personne on delete cascade,
	--Livre emprunte
	foreign key (isbn) references Livre on delete cascade
	
	
);




/******************************* Question 2 *************************************/

insert into Personne values (1, 'Tang', 'Kevin', 'Saint-Priest', 0);
insert into Personne values (2, 'Tran', 'David', 'Villeurbanne', 0);
insert into Personne values (3, 'Elon', 'Musk', 'Loin', 0);
insert into Personne values (4, 'Aulas', 'Jean-Mi', 'Lyon', 0);
insert into Personne values (5, 'Macron', 'Emmanuel', 'Paris', 0);

insert into Livre values (11, 'Livre11', 'Manga', 42, to_timestamp('21-05-1997 12:00:00', 'dd-mm-yyyy hh24:mi:ss'),1);
insert into Livre values (12, 'Livre12', 'Light Novel', 100, to_timestamp('21-05-1997 12:00:01', 'dd-mm-yyyy hh24:mi:ss'),1);

insert into Emprunt values (1, to_timestamp('21-05-1997 14:00:00', 'dd-mm-yyyy hh24:mi:ss'), 11 );
insert into Emprunt values (1, to_timestamp('21-05-1997 14:00:00', 'dd-mm-yyyy hh24:mi:ss'), 11 );




/****************************** Question 3 *********************************/
--essai 1 :
--alter table Emprunt
--add foreign key (isbn, id_emprunteur) references Livre(id_isbn, id_preteur) on delete cascade;

--essai 2 :
--alter table Emprunt
--add constraint emprunteur_est_preteur
--check ( (select count(*) from Livre l, Emprunt e where l.id_preteur = e.id_emprunteur) >= 1 );

create or replace function preteur_existe() returns integer as $$
begin
	return (select count(*) from Livre l, Emprunt e where l.id_preteur = e.id_emprunteur);
end;
$$ language plpgsql;
	
alter table Emprunt 
add constraint emprunteur_est_preteur
check ( preteur_existe() >= 1 );



/*********************************** Question 4 *******************************/
-- objectif : ajouter +4 credits lorsqu'on depose un livre
--fonction
create or replace function ajoute_credits() returns trigger as $$
begin
	update Personne set credits = credits + 4 where idP = new.id_preteur;
	return new; 
end;
$$ LANGUAGE plpgsql;

--drop trigger
--drop trigger if exists ajout_credits on Livre;
--trigger
create trigger ajout_credits
	after insert on Livre 
	for each row
	execute procedure ajoute_credits();

--tests
insert into Livre values (13, 'Livre13', 'Roman', 100, to_timestamp('24-04-2022 12:00:00', 'dd-mm-yyyy hh24:mi:ss'),1);
insert into Livre values (14, 'Livre14', 'BD', 50, to_timestamp('24-04-2022 13:00:00', 'dd-mm-yyyy hh24:mi:ss'),1);
insert into Livre values (15, 'Livre15', 'Manga', 50, to_timestamp('24-04-2022 14:00:00', 'dd-mm-yyyy hh24:mi:ss'),2);


-- objectif : enlever -1 credits lorsqu'on emprunte un livre
--fonction
create or replace function emprunter() returns trigger as $$
declare 
	_id_pret integer; --id de la personne qui a prete le livre
	_credits integer; --nb de credits de la personne qui emprunte
begin 
	-- si l'emprunteur est le preteur du livre
	select id_preteur into _id_pret from Livre where id_isbn = new.isbn;
	if new.id_emprunteur = _id_pret then 
		return new;
	end if;

	--si une personne autre emprunte un livre
	select credits from Personne into _credits where idP = new.id_emprunteur;
	if _credits > 0 then
		update Personne set credits = _credits - 1 where idP = new.id_emprunteur;
		return new;
	end if;
	
	--si l'emprunteur n'a plus de credit
	raise exception 'Emprunt impossible (credits = 0)';
	
end;
$$ language plpgsql;

--drop trigger
--drop trigger if exists emprunt_credits on Emprunt;
--trigger
create trigger emprunt_credits after insert on Emprunt
for each row execute procedure emprunter();

--test
insert into Emprunt values (2, to_timestamp('24-04-2022 12:00:00', 'dd-mm-yyyy hh24:mi:ss'), 11 );
insert into Emprunt values (2, to_timestamp('24-04-2022 14:00:00', 'dd-mm-yyyy hh24:mi:ss'), 13 );
insert into Emprunt values (2, to_timestamp('24-04-2022 14:00:00', 'dd-mm-yyyy hh24:mi:ss'), 14 );
--insert into Emprunt values (2, to_timestamp('24-04-2022 14:00:00', 'dd-mm-yyyy hh24:mi:ss'), 12 );
--insert into Emprunt values (2, to_timestamp('24-04-2022 14:00:00', 'dd-mm-yyyy hh24:mi:ss'), 12 );




/********************************* Question 5 ***********************************/

create or replace function calcul_frais_participation(id_personne integer) returns integer as $$
declare
	_nb_livre_emprunt integer; --nombre de livre empruntes par une personne
	_nb_livre_pret integer; -- nombre de livre pretes par la personne
begin 
	--nb livres empruntes par une personne dans l'annee
	select count(*) from Emprunt into _nb_livre_emprunt where id_emprunteur = id_personne and (select extract(year from date_emprunt)) = (select extract(year from current_timestamp));
	raise notice 'Nombre de livres empruntes cette annee : %', _nb_livre_emprunt;
	--nb livres pretes par une personne dans l'annee
	select count(*) from Livre into _nb_livre_pret where id_preteur = id_personne and (select extract(year from date_pret)) = (select extract(year from current_timestamp));
	raise notice 'Nombre de livres pretes cette annee : %', _nb_livre_pret;

	--si la personne n'a pas prete de livre et donc pas empruntes non plus
	if (_nb_livre_pret = 0) then
		raise notice 'La personne % n a pas prete de livres', id_personne;
		return 0;
	end if;

	--on enleve les livres pretes par la meme personne
	_nb_livre_emprunt := _nb_livre_emprunt - (select count(*) from Emprunt e, Livre l where l.id_isbn = e.isbn and l.id_preteur = e.id_emprunteur and l.id_preteur = id_personne);
	
	--ratio inferieur a 2
	if (_nb_livre_emprunt / _nb_livre_pret)::float <= 2 then
		return 1;
	end if;
	--ratio superieur a 2
	if (_nb_livre_emprunt / _nb_livre_pret)::float > 2 then
		return 2;
	end if;

end;
$$ language plpgsql;

--tests
select calcul_frais_participation(1);
select calcul_frais_participation(2);


/********************************* Question 6 ***********************************/
--On a pas ajoute de contrainte dans le cas ou un livre est prete et non rendu
--une autre personne peut quand meme l'emprunter alors que le livre n'a pas ete rendu
--un meme livre peut donc etre emprunte plusieurs fois au meme moment
--la notion de disponibilite n'existe pas

--il n'y a pas de contrainte sur le nom des livres
--il pourrait y avoir plusieurs livres avec le meme nom

--pas de contraintes concernant les dates
--on peut emprunter des livres a des dates anterieurs a la date du pret



